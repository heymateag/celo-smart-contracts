**Steps to run the smart contract**

1. truffle compile.

2. truffle migrate --reset --network={name of the network}.

   Eg: truffle migrate --reset --network test

   Refer **truffle-config.js** file for different network configuration.

*Documention: https://docs.celo.org/developer-guide/start/hellocontracts*

---

**Steps to deploy the smart contract using nodejs script**

1. truffle compile

2. node celo_deploy.js

*Documention: https://docs.celo.org/developer-guide/start/hello-contract-remote-node*

---