pragma solidity ^0.4.24;

import "./ERC20.sol";
import "./SafeDecimalMath.sol";

contract ToroidToken is ERC20, SafeDecimalMath {

    bool constant DEBUG = true;

	uint secondsPerPeriod = 60*60*24; // example: one day
	// least 1 complete period (2
	// period closings)
	uint periodsMovingAverage = 100 ; // Use moving average of control metric.
	// to avoid race conditions and high-frequency funding and refunding.
	uint constant mandatoryLockinPeriods = 2; // example: funds may stay at
	uint constant tokenFundsPerBaseCoin = 1 ; // 1 wei of collateral
	// equivalent in TRDs base
	// subdivision
	// //100000000000000000; //
	// example: 0.1 ETH per 1 TRD
	// for funding
	// Estimate max cost in gas between fund(), refund() and transfer(), using
	// JavaScript
	uint constant minCostInGasOfTransaction = 21000 ;
	uint collapseTolerance = 9*UNIT/10  ;// ufixed0x128(0.9) ;
	// Options constants
	uint beginOptExecutionDate = 180 ; // team can execute options starting
	// these days after Contract begin.
	uint endOptExecutionDate = 365 ; // team can execute options starting
	// these days after Contract begin.
	uint maxTeamOptAmount = 10000 ; //
	uint teamOptionsMultiplier = 100 ; //
	uint earlyBirdPeriods = 30 ;
	uint earlyBirdDailyInterest = 50 ; // 50 means 2% = 1/50
	// END Constants

	// State Variables
	uint nowDebug = 0 ; 

	uint public currentPeriod ;
	uint public lastUpdateGlobal ;
	uint public creationDate;
	uint public globalRebasement ;
	uint public averageGasPrice = 6000000000 ;
	uint public averageGasPriceWindow = 1000 ;
	mapping (address => uint) public fundBalances;
	mapping (address => uint) public lastFundPeriod ; 
	mapping (address => uint) public balances;
	mapping (address => uint) public lastUpdate;
	mapping (uint => uint) public periodRebasements ;
	mapping (address => uint) public rebasements ;
	mapping (uint => uint) public periodTransactions ;
	uint public totalFunds ;
	uint public totalTokenBase ; 
	uint public transactions ; 
	bool public releaseFunds = false ; // release funds on special conditions.
	
	// data for Allowance from ERC20 interface
	// Owner of account approves the transfer of an amount to another account
	mapping(address => mapping (address => uint256)) allowed;

	// Token Options for Team
	address[] public teamWallet =  [0xD630D5D64D9780ae60A0115128181b6327E25dC3, 0x389652727eDb184a18f5fB90862048515d3636A6];
	uint[] public optionsAvailable =  [10000*UNIT, 10000*UNIT];

	// Events
	event Transfer(address indexed _from, address indexed _to, uint256 _value);

	constructor() public {
		creationDate = block.timestamp; // / secondsPerPeriod; // alias of block.timestamp,
		// translated to days since
		// epoch
		lastUpdateGlobal = 0 ; // creationDate ; //- 1 ;
		periodRebasements[lastUpdateGlobal] = UNIT; // equivalent to
		// 1.0, so no
		// rebasement
		// initially.
	}

	// MODIFIERS
	modifier updateCurrentPeriod()
	{
		currentPeriod = safeSub(safeDiv(block.timestamp,uint(secondsPerPeriod)), safeDiv(creationDate, uint(secondsPerPeriod)));
		_;
	}

	// FOR DEBUGGIN ONLY!, REMOVE LATER!
	function setSecondsPerPeriod(uint secs) 
	public 
	{
	    if (DEBUG)
    		secondsPerPeriod = secs;
	}

	// FOR DEBUGGIN ONLY!, REMOVE LATER!
	function setPeriodsMovingAverage(uint periods) 
	public 
	{
	    if (DEBUG)
    		periodsMovingAverage = periods;
	}


	// PRIVATE FUNCTIONS

	function updateBalance(address wallet) 
	updateCurrentPeriod()
	public 
	{

		if (lastUpdate[wallet] == 0) {
			rebasements[wallet] = UNIT ; // equivalent to 1.0 in our
			// fixed point scale.
		}
		else {
			if (lastUpdate[wallet] < currentPeriod) {
				uint balance = balances[wallet] ;
				//totalTokenBase = totalTokenBase - balance ;
				for (uint period = lastUpdate[wallet]; period < currentPeriod; period++) {
				    // check zeros in case of missing rebasements some day.
				    if (periodRebasements[period]==0) {
				        periodRebasements[period] = UNIT;
				    }
					balance = safeMul_dec(balance, periodRebasements[period] ) ;
				}
				// back to interger wei from fixed point
				balances[wallet] = balance ;
				//totalTokenBase = totalTokenBase + balance ;
			}
		}
		lastUpdate[wallet] = currentPeriod ;
	}

	function isTeamWallet(address wallet) public view returns (int teamIndex) {
		int ret = -1 ;
		for (int w = 0; w < int(teamWallet.length); w++) {
			if (wallet == teamWallet[uint(w)]) {
				ret = w ;
				break ;
			}
		}
		return w ;
	}

	// The rate returned is in UNIT scale (example 1e18 mean 1)
	function updateRebasementGlobal() 
	updateCurrentPeriod()
	private 
	returns (uint rebasement) 
	{
		// update previous day
		uint periods = currentPeriod; // - creationDate ; 
		// Just an example, of possible bootstrap premiums
		// for early investors = 1 + 1/50 , 2% each Initial Offering period.
		if (currentPeriod < earlyBirdPeriods) {
    		uint earlyAdoptersPremium = UNIT + UNIT / earlyBirdDailyInterest ;
		}
		// Moving Average
		if (periods > 1) {
		    periodTransactions[currentPeriod-1] = safeDiv_dec(periodTransactions[currentPeriod-1], periodsMovingAverage) ;
		    periodTransactions[currentPeriod-1] += safeDiv_dec(safeMul_dec(periodTransactions[currentPeriod-2], (periodsMovingAverage-1)), periodsMovingAverage) ;
		} 
		
		uint absRateControl = 0 ;
		uint rateControl = 0 ;
		if (periodTransactions[currentPeriod-2] == 0)
			rateControl = 0 ;
		else {
			// pT[t-1] / pT[t-2]
			rateControl = safeDiv_dec(intToDec(periodTransactions[currentPeriod-1]), intToDec(periodTransactions[currentPeriod-2]));
		}
		// Reflective Currency manipulation limit.
		// Worst case scenario, the attacker jumps transactions from 1 to a big
		// number.

		int deltaControl = int(periodTransactions[currentPeriod-1]) -int(periodTransactions[currentPeriod-2]); // *
		
		// maxPriceInGasOfTransaction
		// ;
		// abs(a-b)
		if (deltaControl < 0) {
			deltaControl *= -1 ;
		}
		uint deltaControlUnsigned = uint(deltaControl);
		// use opposite direction for rebasement
		uint finalRate = 0 ;
		if (rateControl >= 0) {
			// Min Positive
			// min(rvol, costPerTransaction*v/initialSupply )
			uint rateProtection = safeMul_dec(intToDec(averageGasPrice), intToDec(minCostInGasOfTransaction)); 
			rateProtection = safeMul_dec(rateProtection, intToDec(deltaControlUnsigned)) ;
			rateProtection = safeDiv_dec(rateProtection, intToDec(totalTokenBase)) ;
			// min(rvol, costPerTransaction*v/initialSupply )
			if ( absRateControl < rateProtection )
				finalRate = rateControl ;
			else
				finalRate = safeAdd(rateProtection, UNIT) ;
		}
		// do (R + 1.0 ) * earlyAdoptersRebasement
		if (currentPeriod < earlyBirdPeriods) {
        	return safeMul_dec(finalRate, earlyAdoptersPremium);
		} else {
		    return finalRate ; // rate
		}
	}

	// EXTERNAL FUNCTIONS

	function fundBalanceOf() public view returns (uint256 balance) {
		// updateBalance(addr) ;
		return fundBalances[msg.sender];
	}

	function fund() public payable returns (bool success) {
		// Update slow moving average for Gas Price
		averageGasPrice = safeDiv(safeMul(averageGasPrice, (averageGasPriceWindow-1)),averageGasPriceWindow) ;
		averageGasPrice = safeAdd( averageGasPrice , safeDiv(tx.gasprice,averageGasPriceWindow)) ;

		// updateBalance(msg.sender) ; // to avoid funding of past rebasements
		// in case of price falling.
		// Check team options
		uint fundMultiplier = 1 ;
		uint ageInPeriods = 0 ;
		ageInPeriods = safeSub( safeDiv(block.timestamp, secondsPerPeriod) , safeDiv(creationDate, secondsPerPeriod) )  ;
		

		/*
		 * int teamIndex = isTeamWallet(msg.sender) ; if (teamIndex >= 0 &&
		 * ageInPeriods > beginOptExecutionDate && ageInPeriods <
		 * endOptExecutionDate){ // belong to team fundMultiplier =
		 * teamOptionsMultiplier ; // we use return because we have nothing to
		 * revert and also throw is not working in our test deployment. if
		 * (optionsAvailable[uint(teamIndex)]*UNIT <
		 * msg.value*fundMultiplier) return false;
		 * optionsAvailable[uint(teamIndex)] -= msg.value*fundMultiplier ; }
		 */
		fundBalances[msg.sender] += msg.value*fundMultiplier ;
		// one-way peg, for one period there is no incentive to dump the new
		// coins.
		// although we can reimburse the original fund at any time, see refund()
		// In this example the one-way peg is 1 TRD per 1.0 ETH of funding,
		// but there is not minimum a-priori.
		balances[msg.sender] += msg.value * tokenFundsPerBaseCoin ;
		lastFundPeriod[msg.sender] = safeSub( safeDiv(block.timestamp, secondsPerPeriod), safeDiv(creationDate, secondsPerPeriod) ) ; 

		// periodTransactions[currentPeriod] = periodTransactions[currentPeriod]
		// + 1 ;
		totalFunds = safeAdd( totalFunds, msg.value ) ;
		totalTokenBase = safeAdd(totalTokenBase, msg.value );
		return true ;
	}


	function getLastFundPeriod(address sender) public constant returns (uint256 period) {
		return lastFundPeriod[sender];
	}


	function getCurrentPeriod() public constant returns (uint256 period) {
                return currentPeriod;
        }



	function refund()
	public
	updateCurrentPeriod()
	payable 
	returns (bool success)
	{
		// Update slow moving average for Gas Price
		averageGasPrice = safeDiv(safeMul(averageGasPrice, (averageGasPriceWindow-1)),averageGasPriceWindow) ;
		averageGasPrice = safeAdd( averageGasPrice , safeDiv(tx.gasprice,averageGasPriceWindow)) ;

		// Minimum Holding period check.
		if (lastFundPeriod[msg.sender] + mandatoryLockinPeriods - 1 >= currentPeriod) {
			return false ;
		}
		if (fundBalances[msg.sender] < msg.value) return false;
		updateBalance(msg.sender) ;
		// Do check for TRD in wallet if fund release is off.
		if (releaseFunds == false) {    	
			// Check balance of TRDs.
			// you need 1 basecoin ETH per 
			uint tokenBaseCoinRatio = UNIT * totalTokenBase / totalFunds ;
			if (balances[msg.sender] < msg.value * tokenBaseCoinRatio / UNIT ) return false;
		}
		fundBalances[msg.sender] = fundBalances[msg.sender] - msg.value ;
		balances[msg.sender] = balances[msg.sender] - msg.value * tokenBaseCoinRatio / UNIT ;
		totalFunds = totalFunds - msg.value ;
		//totalTokenBase = totalTokenBase - msg.value ;  
		if (!msg.sender.send(msg.value)) {			
			return false;
		}
		// periodTransactions[currentPeriod] = periodTransactions[currentPeriod]
		// + 1 ;

		return true;
	}

	function transfer(address _to, uint256 _value) 
	public 
	updateCurrentPeriod()
	returns(bool success)
	{
		// Update slow moving average for Gas Price
		averageGasPrice = safeDiv(safeMul(averageGasPrice, (averageGasPriceWindow-1)),averageGasPriceWindow) ;
		averageGasPrice = safeAdd( averageGasPrice , safeDiv(tx.gasprice,averageGasPriceWindow)) ;

		if (_to == msg.sender) return true ;
		updateBalance(msg.sender) ;
		updateBalance(_to) ;
		// Default assumes totalSupply can't be over max (2^256 - 1).
		// If your token leaves out totalSupply and can issue more tokens as
		// time goes on, you need to check if it doesn't wrap.
		// Replace the if with this one instead.
		// if (balances[msg.sender] >= _value && balances[_to] + _value >
		// balances[_to]) {
		if (balances[msg.sender] >= _value && _value > 0) {
		    
			balances[msg.sender] -= _value;
			balances[_to] += _value;
			emit Transfer(msg.sender, _to, _value);
			periodTransactions[currentPeriod] += 1 ;
			transactions += 1 ;
		        //Transfer(msg.sender, _to, _value);
			return true;
			
		} else { 
		    return false; 
		    
		}
	}

	// A big pool of resilient friends will poll this method
	// , for example, 2 minutes before midnight. Only the first poller
	// will go through.
	// TODO: use Alarm Clock from pipinmerriam
	// (https://github.com/pipermerriam/ethereum-alarm-clock)
	function updateRebasement()
	updateCurrentPeriod()
	external
	returns(bool success)
	{
		// if already updated for current period, abort.
		if (lastUpdateGlobal >= currentPeriod) return false;
		// Compute rebasement
		periodRebasements[currentPeriod] = updateRebasementGlobal() ;
		totalTokenBase = safeMul_dec(totalTokenBase,periodRebasements[currentPeriod]) ;
		lastUpdateGlobal = currentPeriod ; 
        return true;
	}
	
	// CONSTANT FUNCTIONS

    function totalSupply() public constant returns (uint supply) {
        return totalTokenBase;
    }

    function balanceOf(address _owner) public constant returns (uint balance) {
		return balances[_owner];
	}
	

    function nowSeconds() public constant returns (uint256 timestamp){
         return block.timestamp;
     }
     
    function tokenToBaseCoinRatio() public constant returns (uint256 timestamp){
         return      UNIT * totalTokenBase / totalFunds ;
     }
 

     

	// NOT IMPLEMENTED
	
    function transferFrom(
         address _from,
         address _to,
         uint256 _amount
     ) public returns (bool success) {
         
        // check the balances are up-to-date, rebasement updated.
		updateBalance(_from) ;
		updateBalance(_to) ;

        if (balances[_from] >= _amount
             && allowed[_from][msg.sender] >= _amount
             && _amount > 0
             && balances[_to] + _amount > balances[_to]) {
             balances[_from] -= _amount;
             allowed[_from][msg.sender] -= _amount;
             balances[_to] += _amount;
             return true;
        } else {
            return false;
        }
    }

    // Allow _spender to withdraw from your account, multiple times, up to the _value amount.
    // If this function is called again it overwrites the current allowance with _value.
    function approve(address _spender, uint256 _amount) public returns (bool success) {
         allowed[msg.sender][_spender] = _amount;
         return true;
    }

    function allowance(address _owner, address _spender) public constant returns (uint256 remaining) {
        return allowed[_owner][_spender];
    }


}


