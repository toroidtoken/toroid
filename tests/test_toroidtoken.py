import time

def test_toroid(chain):
    toroid, _ = chain.provider.get_or_deploy_contract('ToroidToken')

    funds = toroid.call().fundBalanceOf()
    assert funds == 0


def test_fund(chain):
    toroid, _ = chain.provider.get_or_deploy_contract('ToroidToken')

    set_txn_hash = toroid.transact().setSecondsPerPeriod(5)
    chain.wait.for_receipt(set_txn_hash)
    
    set_txn_hash = toroid.transact({'value':1}).fund()
    chain.wait.for_receipt(set_txn_hash)

    funds = toroid.call().fundBalanceOf()
    assert funds == 1

    
def test_send_token(chain):
    toroid, _ = chain.provider.get_or_deploy_contract('ToroidToken')

    set_txn_hash = toroid.transact().setSecondsPerPeriod(5)
    chain.wait.for_receipt(set_txn_hash)
    
    set_txn_hash = toroid.transact({'value':2}).fund()
    chain.wait.for_receipt(set_txn_hash)

    balance0 = toroid.call().balanceOf(chain.web3.eth.accounts[0])
    assert balance0 == 2

    set_txn_hash = toroid.transact().transfer(chain.web3.eth.accounts[1],2)
    chain.wait.for_receipt(set_txn_hash)

    balance1 = toroid.call().balanceOf(chain.web3.eth.accounts[1])
    assert balance1 == 2
    balance0 = toroid.call().balanceOf(chain.web3.eth.accounts[0])
    assert balance0 == 0

def test_total_supply(chain):
    toroid, _ = chain.provider.get_or_deploy_contract('ToroidToken')

    set_txn_hash = toroid.transact().setSecondsPerPeriod(5)
    chain.wait.for_receipt(set_txn_hash)

    set_txn_hash = toroid.transact({'value':2}).fund()
    chain.wait.for_receipt(set_txn_hash)

    supply = toroid.call().totalSupply()
    assert supply == 2
    set_txn_hash = toroid.transact({'value':1, 'from':chain.web3.eth.accounts[2]}).fund()
    chain.wait.for_receipt(set_txn_hash)

    supply = toroid.call().balanceOf(chain.web3.eth.accounts[2])
    assert supply == 1

    
def test_no_refund_balance_after_one_period(chain):
    toroid, _ = chain.provider.get_or_deploy_contract('ToroidToken')

    set_txn_hash = toroid.transact().setSecondsPerPeriod(5)
    chain.wait.for_receipt(set_txn_hash)

    set_txn_hash = toroid.transact({'value':1, 'from':chain.web3.eth.accounts[2]}).fund()
    chain.wait.for_receipt(set_txn_hash)

    supply = toroid.call().balanceOf(chain.web3.eth.accounts[2])
    assert supply == 1

    set_txn_hash = toroid.transact({'value':1, 'from':chain.web3.eth.accounts[2]}).refund()
    chain.wait.for_receipt(set_txn_hash)

    supply = toroid.call().balanceOf(chain.web3.eth.accounts[2])
    assert supply == 1

    
def test_refund_balance_after_two_periods(chain):
    toroid, _ = chain.provider.get_or_deploy_contract('ToroidToken')
    
    set_txn_hash = toroid.transact().setSecondsPerPeriod(5)
    chain.wait.for_receipt(set_txn_hash)

    set_txn_hash = toroid.transact({'value':1, 'from':chain.web3.eth.accounts[2]}).fund()
    chain.wait.for_receipt(set_txn_hash)

    set_txn_hash = toroid.transact({'value':1, 'from':chain.web3.eth.accounts[2]}).fund()
    chain.wait.for_receipt(set_txn_hash)

    supply = toroid.call().balanceOf(chain.web3.eth.accounts[2])
    assert supply == 2

    set_txn_hash = toroid.transact({'value':1, 'from':chain.web3.eth.accounts[2]}).fund()
    chain.wait.for_receipt(set_txn_hash)

    supply = toroid.call().balanceOf(chain.web3.eth.accounts[2])
    assert supply == 3

    set_txn_hash = toroid.transact({'value':3, 'from':chain.web3.eth.accounts[2]}).refund()
    chain.wait.for_receipt(set_txn_hash)

    supply = toroid.call().balanceOf(chain.web3.eth.accounts[2])
    assert supply == 0



def test_partial_refund_balance_after_two_periods(chain):
    toroid, _ = chain.provider.get_or_deploy_contract('ToroidToken')

    set_txn_hash = toroid.transact().setSecondsPerPeriod(5)
    chain.wait.for_receipt(set_txn_hash)

    #open('out.log','aw').write('\n-------------------\n'+time.ctime() + ' ' + str(toroid.call().nowSeconds()) + '\n')
    #open('out.log','aw').write(time.ctime() + ' lastFundPeriod=' + str(toroid.call().getLastFundPeriod(chain.web3.eth.accounts[2])) + '\n')
    #open('out.log','aw').write(time.ctime() + ' currentPeriod=' + str(toroid.call().getCurrentPeriod()) + '\n')
    #open('out.log','aw').write(time.ctime() + ' balanceOf2=' + str(toroid.call().balanceOf(chain.web3.eth.accounts[2])) + '\n')                                                                    
    set_txn_hash = toroid.transact({'value':1, 'from':chain.web3.eth.accounts[2]}).fund()
    chain.wait.for_receipt(set_txn_hash)

    set_txn_hash = toroid.transact({'value':1, 'from':chain.web3.eth.accounts[2]}).fund()
    chain.wait.for_receipt(set_txn_hash)

    supply = toroid.call().balanceOf(chain.web3.eth.accounts[2])
    assert supply == 2

    #open('out.log','aw').write(time.ctime() + ' ' + str(toroid.call().nowSeconds()) + '\n')
    #open('out.log','aw').write(time.ctime() + ' lastFundPeriod=' + str(toroid.call().getLastFundPeriod(chain.web3.eth.accounts[2])) + '\n')
    #open('out.log','aw').write(time.ctime() + ' currentPeriod=' + str(toroid.call().getCurrentPeriod()) + '\n')
    #open('out.log','aw').write(time.ctime() + ' balanceOf2=' + str(toroid.call().balanceOf(chain.web3.eth.accounts[2])) + '\n') 
    
    set_txn_hash = toroid.transact({'value':1, 'from':chain.web3.eth.accounts[2]}).fund()
    chain.wait.for_receipt(set_txn_hash)

    supply = toroid.call().balanceOf(chain.web3.eth.accounts[2])
    assert supply == 3

    #open('out.log','aw').write(time.ctime() + ' ' + str(toroid.call().nowSeconds()) + '\n')
    #open('out.log','aw').write(time.ctime() + ' lastFundPeriod=' + str(toroid.call().getLastFundPeriod(chain.web3.eth.accounts[2])) + '\n')
    #open('out.log','aw').write(time.ctime() + ' currentPeriod=' + str(toroid.call().getCurrentPeriod()) + '\n')
    #open('out.log','aw').write(time.ctime() + ' balanceOf2=' + str(toroid.call().balanceOf(chain.web3.eth.accounts[2])) + '\n') 
    
    set_txn_hash = toroid.transact({'value':2, 'from':chain.web3.eth.accounts[2]}).refund()
    chain.wait.for_receipt(set_txn_hash)

    supply = toroid.call().balanceOf(chain.web3.eth.accounts[2])
    #open('out.log','aw').write(time.ctime() + ' ' + str(toroid.call().nowSeconds()) + '\n')
    #open('out.log','aw').write(time.ctime() + ' lastFundPeriod=' + str(toroid.call().getLastFundPeriod(chain.web3.eth.accounts[2])) + '\n')
    #open('out.log','aw').write(time.ctime() + ' currentPeriod=' + str(toroid.call().getCurrentPeriod()) + '\n')
    #open('out.log','aw').write(time.ctime() + ' balanceOf2=' + str(toroid.call().balanceOf(chain.web3.eth.accounts[2])) + '\n')

    supply = toroid.call().balanceOf(chain.web3.eth.accounts[2])
    assert supply == 1


def test_refund_too_much(chain):
    toroid, _ = chain.provider.get_or_deploy_contract('ToroidToken')

    set_txn_hash = toroid.transact().setSecondsPerPeriod(5)
    chain.wait.for_receipt(set_txn_hash)

    set_txn_hash = toroid.transact({'value':3, 'from':chain.web3.eth.accounts[2]}).fund()
    chain.wait.for_receipt(set_txn_hash)
    
    supply = toroid.call().balanceOf(chain.web3.eth.accounts[2])
    assert supply == 3

    set_txn_hash = toroid.transact({'value':3, 'from':chain.web3.eth.accounts[2]}).fund()
    chain.wait.for_receipt(set_txn_hash)

    supply = toroid.call().balanceOf(chain.web3.eth.accounts[2])
    assert supply == 6
    
    set_txn_hash = toroid.transact({'value':7, 'from':chain.web3.eth.accounts[2]}).refund()
    chain.wait.for_receipt(set_txn_hash)

    balance = toroid.call().balanceOf(chain.web3.eth.accounts[2])
    assert balance == 6

    
def test_rebasement(chain):
    toroid, _ = chain.provider.get_or_deploy_contract('ToroidToken')

    set_txn_hash = toroid.transact().setSecondsPerPeriod(5)
    chain.wait.for_receipt(set_txn_hash)

    #open('out.log','aw').write('\n-------------------\n'+time.ctime() + ' ' + str(toroid.call().nowSeconds()) + '\n')
    #open('out.log','aw').write(time.ctime() + ' lastFundPeriod=' + str(toroid.call().getLastFundPeriod(chain.web3.eth.accounts[2])) + '\n')
    #open('out.log','aw').write(time.ctime() + ' currentPeriod=' + str(toroid.call().getCurrentPeriod()) + '\n')
    #open('out.log','aw').write(time.ctime() + ' balanceOf2=' + str(toroid.call().balanceOf(chain.web3.eth.accounts[2])) + '\n')
    #open('out.log','aw').write(time.ctime() + ' balanceOf1=' + str(toroid.call().balanceOf(chain.web3.eth.accounts[1])) + '\n')
    
    set_txn_hash = toroid.transact({'value':10, 'from':chain.web3.eth.accounts[2]}).fund()
    chain.wait.for_receipt(set_txn_hash)

    #open('out.log','aw').write(time.ctime() + ' ' + str(toroid.call().nowSeconds()) + '\n')
    #open('out.log','aw').write(time.ctime() + ' lastFundPeriod=' + str(toroid.call().getLastFundPeriod(chain.web3.eth.accounts[2])) + '\n')
    #open('out.log','aw').write(time.ctime() + ' currentPeriod=' + str(toroid.call().getCurrentPeriod()) + '\n')
    #open('out.log','aw').write(time.ctime() + ' balanceOf2=' + str(toroid.call().balanceOf(chain.web3.eth.accounts[2])) + '\n')
    #open('out.log','aw').write(time.ctime() + ' balanceOf1=' + str(toroid.call().balanceOf(chain.web3.eth.accounts[1])) + '\n')
    
    supply = toroid.call().balanceOf(chain.web3.eth.accounts[2])
    assert supply == 10

    set_txn_hash = toroid.transact({'from':chain.web3.eth.accounts[2]}).transfer(chain.web3.eth.accounts[1],10)
    chain.wait.for_receipt(set_txn_hash)

    #open('out.log','aw').write(time.ctime() + ' ' + str(toroid.call().nowSeconds()) + '\n')
    #open('out.log','aw').write(time.ctime() + ' lastFundPeriod=' + str(toroid.call().getLastFundPeriod(chain.web3.eth.accounts[2])) + '\n')
    #open('out.log','aw').write(time.ctime() + ' currentPeriod=' + str(toroid.call().getCurrentPeriod()) + '\n')
    #open('out.log','aw').write(time.ctime() + ' balanceOf2=' + str(toroid.call().balanceOf(chain.web3.eth.accounts[2])) + '\n')
    #open('out.log','aw').write(time.ctime() + ' balanceOf1=' + str(toroid.call().balanceOf(chain.web3.eth.accounts[1])) + '\n')

    supply = toroid.call().balanceOf(chain.web3.eth.accounts[1])
    assert supply == 10
    
    set_txn_hash = toroid.transact({'from':chain.web3.eth.accounts[1]}).transfer(chain.web3.eth.accounts[2],10)
    chain.wait.for_receipt(set_txn_hash)

    #open('out.log','aw').write(time.ctime() + ' ' + str(toroid.call().nowSeconds()) + '\n')
    #open('out.log','aw').write(time.ctime() + ' lastFundPeriod=' + str(toroid.call().getLastFundPeriod(chain.web3.eth.accounts[2])) + '\n')
    #open('out.log','aw').write(time.ctime() + ' currentPeriod=' + str(toroid.call().getCurrentPeriod()) + '\n')
    #open('out.log','aw').write(time.ctime() + ' balanceOf2=' + str(toroid.call().balanceOf(chain.web3.eth.accounts[2])) + '\n')
    #open('out.log','aw').write(time.ctime() + ' balanceOf1=' + str(toroid.call().balanceOf(chain.web3.eth.accounts[1])) + '\n')

    supply = toroid.call().balanceOf(chain.web3.eth.accounts[2])
    assert supply == 10
    
    set_txn_hash = toroid.transact({'from':chain.web3.eth.accounts[2]}).updateRebasement()
    chain.wait.for_receipt(set_txn_hash)

    set_txn_hash = toroid.transact({'from':chain.web3.eth.accounts[2]}).updateBalance(chain.web3.eth.accounts[2])
    chain.wait.for_receipt(set_txn_hash)

    #open('out.log','aw').write(time.ctime() + ' ' + str(toroid.call().nowSeconds()) + '\n')
    #open('out.log','aw').write(time.ctime() + ' lastFundPeriod=' + str(toroid.call().getLastFundPeriod(chain.web3.eth.accounts[2])) + '\n')
    #open('out.log','aw').write(time.ctime() + ' currentPeriod=' + str(toroid.call().getCurrentPeriod()) + '\n')
    #open('out.log','aw').write(time.ctime() + ' balanceOf2=' + str(toroid.call().balanceOf(chain.web3.eth.accounts[2])) + '\n')
    #open('out.log','aw').write(time.ctime() + ' balanceOf1=' + str(toroid.call().balanceOf(chain.web3.eth.accounts[1])) + '\n')
    
    supply = toroid.call().balanceOf(chain.web3.eth.accounts[2])
    assert supply == 20

    # updateRebasement
    
