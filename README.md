# GIF Core Contracts

This repository holds the GIF core contracts and tools to develop, test and deploy GIF instances.

## Clone Repository

```bash
git clone https://github.com/etherisc/gif-contracts.git
cd gif-contracts
```

## Create Brownie Docker Image

[Brownie](https://eth-brownie.readthedocs.io/en/stable) is used for development of the contracts in this repository.

Alternatively to installing a python development environment and the brownie framework, wokring with Brownie is also possible via Docker.

For building the `brownie` docker image used in the samples below, follow the instructions in [gif-brownie](https://github.com/etherisc/gif-brownie).


## Run Brownie Container

```bash
docker run -it --rm -v $PWD:/projects brownie
```

## Compile the GIF Core Contracts

Inside the Brownie container compile the contracts/interfaces

```bash
brownie compile --all
```

## Run GIF Unit Tests

Run the unit tests
```bash
brownie test
```

or to execute the tests in parallel

```
brownie test -n auto
```

_Note_: Should the tests fail when running them in parallel, the test execution probably creates too much load on the system. 
In this case replace the `auto` keyword in the command with the number of executors (use at most the number of CPU cores available on your system). 

## Deploy and Use GIF Interactively

Start the Brownie console that shows the `>>>` console prompt.
```bash
brownie console
```

Example session inside the Brownie console

* Deployment of a GIF instance
* Deployment and usage of Test oracle and product

```bash
# --- imports ---
import uuid
from scripts.product import GifInstance, GifTestOracle, GifTestProduct, GifTestRiskpool
from scripts.util import s2b, b2s

# --- create instance and accounts setup ---
instanceOperator=accounts[0]
instanceWallet=accounts[1]
oracleProvider=accounts[2]
chainlinkNodeOperator=accounts[3]
riskpoolKeeper=accounts[4]
riskpoolWallet=accounts[5]
investor=accounts[6]
productOwner=accounts[7]
insurer=accounts[8]
customer=accounts[9]
customer2=accounts[10]

# --- dummy coin setup ---
testCoin = TestCoin.deploy({'from': instanceOperator})
testCoin.transfer(investor, 10**6, {'from': instanceOperator})
testCoin.transfer(customer, 10**6, {'from': instanceOperator})

# --- create instance setup ---
# instance=GifInstance(registryAddress='0xe7D6c54cf8Bd798edA9E9A3Aa094Fb01EF34C251', owner=owner)
instance = GifInstance(owner, feeOwner)
service = instance.getInstanceService()

instance.getRegistry()

# --- deploy product (and oracle) ---
capitalization = 10**18
gifRiskpool = GifTestRiskpool(instance, riskpoolKeeper, capitalOwner, capitalization)
gifOracle = GifTestOracle(instance, oracleProvider, name=str(uuid.uuid4())[:8])
gifProduct = GifTestProduct(
  instance,
  testCoin,
  capitalOwner,
  feeOwner,
  productOwner,
  gifOracle,
  gifRiskpool,
  name=str(uuid.uuid4())[:8])

riskpool = gifRiskpool.getContract()
oracle = gifOracle.getContract()
product = gifProduct.getContract()
treasury = instance.getTreasury()

# --- fund riskpool ---
testCoin.approve(treasury, 3000, {'from': riskpoolKeeper})
riskpool.createBundle(bytes(0), 1000, {'from':riskpoolKeeper})
riskpool.createBundle(bytes(0), 2000, {'from':riskpoolKeeper})

# --- policy application spec  ---
premium = 100
sumInsured = 1000
metaData = s2b('')
applicationData = s2b('')

# --- premium funding setup
treasuryAddress = instance.getTreasury().address
testCoin.transfer(customer, premium, {'from': owner})
testCoin.approve(treasuryAddress, premium, {'from': customer})

# --- create policies ---
txPolicy1 = product.applyForPolicy(premium, sumInsured, metaData, applicationData, {'from':customer})
txPolicy2 = product.applyForPolicy(premium, sumInsured, metaData, applicationData, {'from':customer})
```

Brownie console commands to deploy/use the example product

```shell
from scripts.area_yield_index import GifAreaYieldIndexOracle, GifAreaYieldIndexProduct

from scripts.setup import fund_riskpool, fund_customer
from tests.test_area_yield import create_peril 

#--- area yield product
collateralization = 10**18
gifTestRiskpool = GifTestRiskpool(
  instance, 
  riskpoolKeeper, 
  capitalOwner, 
  collateralization)

gifAreaYieldIndexOracle = GifAreaYieldIndexOracle(
  instance, 
  oracleProvider)

gifAreaYieldIndexProduct = GifAreaYieldIndexProduct(
  instance, 
  testCoin,
  capitalOwner,
  feeOwner,
  productOwner,
  riskpoolKeeper,
  customer,
  gifAreaYieldIndexOracle,
  gifTestRiskpool)


riskpool = gifTestRiskpool.getContract()
oracle = gifAreaYieldIndexOracle.getContract()
product = gifAreaYieldIndexProduct.getContract()

# funding of riskpool and customers
riskpoolWallet = capitalOwner
investor = riskpoolKeeper # investor=bundleOwner
insurer = productOwner # role required by area yield index product

token = gifAreaYieldIndexProduct.getToken()
riskpoolFunding = 200000
fund_riskpool(
    instance, 
    owner, 
    riskpoolWallet, 
    riskpool, 
    investor, 
    token, 
    riskpoolFunding)

customerFunding = 500
fund_customer(instance, owner, customer, token, customerFunding)
fund_customer(instance, owner, customer2, token, customerFunding)

uai1 = '1'
uai2 = '2'
cropId1 = 1001
cropId2 = 1002
premium1 = 200
premium2 = 300
sumInsured = 60000

# batched policy creation
perils = [
        create_peril(uai1, cropId1, premium1, sumInsured, customer),
        create_peril(uai2, cropId2, premium2, sumInsured, customer2),
    ]

tx = product.applyForPolicy(perils, {'from': insurer})

# returns tuple for created process ids
processIds = tx.return_value

product.triggerResolutions(uai1, {'from': insurer})

```


In case things go wrong you can information regarding the last transaction via history.

```bash
history[-1].info()
```

## Deployment to Live Networks

Deployments to live networks can be done with brownie console as well.

Example for the deployment to Polygon test

```bash
brownie console --network polygon-test

# in console
owner = accounts.add()
# will generate a new account and prints the mnemonic here

owner.address
# will print the owner address that you will need to fund first
```

Use Polygon test [faucet](https://faucet.polygon.technology/) to fund the owner address
```bash
from scripts.instance import GifInstance

# publishes source code to the network
instance = GifInstance(owner, publishSource=True)

# after the deploy print the registry address
instance.getRegistry().address
```

After a successful deploy check the registry contract in the Polygon [testnet explorer](https://mumbai.polygonscan.com/).

To check all contract addresses you may use the instance python script inside the brownie container as follows.
```bash
# 0x2852593b21796b549555d09873155B25257F6C38 is the registry contract address
brownie run scripts/instance.py dump_sources 0x2852593b21796b549555d09873155B25257F6C38 --network polygon-test
```

## Full Deployment with Example Product

Before attempting to deploy the setup on a life chain ensure that the
`instanceOperator` has sufficient funds to cover the setup.

For testnets faucet funds may be used

* [avax-test (Fuji (C-Chain))](https://faucet.avax.network/)
* [polygon-test](https://faucet.polygon.technology/)

Using the ganache scenario shown below ensures that all addresses used are sufficiently funded.

```bash
from scripts.deploy import (
    stakeholders_accounts_ganache,
    check_funds,
    amend_funds,
    deploy,
    from_registry,
    from_component,
)

from scripts.instance import (
  GifInstance, 
  dump_sources
)

from scripts.util import (
  s2b, 
  b2s, 
  contract_from_address,
)

# for ganche the command below may be used
# for other chains, use accounts.add() and record the mnemonics
a = stakeholders_accounts_ganache()

# check_funds checks which stakeholder accounts need funding for the deploy
# also, it checks if the instanceOperator has a balance that allows to provided
# the missing funds for the other accounts
check_funds(a)

# amend_funds transfers missing funds to stakeholder addresses using the
# avaulable balance of the instanceOperator
amend_funds(a)

publishSource=False
d = deploy(a, publishSource)

(
componentOwnerService,customer1,customer2,erc20Token,instance,instanceOperator,instanceOperatorService,instanceService,
instanceWallet,insurer,investor,oracle,oracleProvider,processId1,processId2,product,productOwner,riskId1,riskId2,
riskpool,riskpoolKeeper,riskpoolWallet
)=(
d['componentOwnerService'],d['customer1'],d['customer2'],d['erc20Token'],d['instance'],d['instanceOperator'],d['instanceOperatorService'],d['instanceService'],
d['instanceWallet'],d['insurer'],d['investor'],d['oracle'],d['oracleProvider'],d['processId1'],d['processId2'],d['product'],d['productOwner'],d['riskId1'],d['riskId2'],
d['riskpool'],d['riskpoolKeeper'],d['riskpoolWallet']
)

# the deployed setup can now be used
# example usage
instanceOperator
instance.getRegistry()
instanceService.getInstanceId()

product.getId()
b2s(product.getName())

customer1
instanceService.getMetadata(processId1)
instanceService.getApplication(processId1)
instanceService.getPolicy(processId1)
```

For a first time setup on a live chain the setup below can be used.

IMPORTANT: Make sure to write down the generated mnemonics for the
stakeholder accounts. To reuse the same accounts replace `accounts.add` 
with `accounts.from_mnemonic` using the recorded mnemonics.

```bash
instanceOperator=accounts.add()
instanceWallet=accounts.add()
oracleProvider=accounts.add()
chainlinkNodeOperator=accounts.add()
riskpoolKeeper=accounts.add()
riskpoolWallet=accounts.add()
investor=accounts.add()
productOwner=accounts.add()
insurer=accounts.add()
customer1=accounts.add()
customer2=accounts.add()

a = {
  'instanceOperator': instanceOperator,
  'instanceWallet': instanceWallet,
  'oracleProvider': oracleProvider,
  'chainlinkNodeOperator': chainlinkNodeOperator,
  'riskpoolKeeper': riskpoolKeeper,
  'riskpoolWallet': riskpoolWallet,
  'investor': investor,
  'productOwner': productOwner,
  'insurer': insurer,
  'customer1': customer1,
  'customer2': customer2,
}
```

To interact with an existing setup use the following helper methods as shown below.

```bash
from scripts.deploy import (
    from_registry,
    from_component,
)

from scripts.instance import (
  GifInstance, 
)

from scripts.util import (
  s2b, 
  b2s, 
  contract_from_address,
)

# for the case of a known registry address, 
# eg '0xE7eD6747FaC5360f88a2EFC03E00d25789F69291'
(instance, product, oracle, riskpool) = from_registry('0xE7eD6747FaC5360f88a2EFC03E00d25789F69291')

# or for a known address of a component, eg
# eg product address '0xF039D8acecbB47763c67937D66A254DB48c87757'
(instance, product, oracle, riskpool) = from_component('0xF039D8acecbB47763c67937D66A254DB48c87757')
```