const Kit = require('@celo/contractkit')
const kit = Kit.newKit('https://alfajores-forno.celo-testnet.org')

module.exports = {
  networks: {
    // Test network
    test: {
      host: "127.0.0.1",
      port: 7545,
      network_id: "*"
    },
    // Celo Alfajores network
    alfajores_local: {
      host: "127.0.0.1",
      port: 8545,
      network_id: 44787
    },
    alfajores: {
      provider: kit.connection.web3.currentProvider, // CeloProvider
      network_id: 44787     ,                         // Alfajores network id
    }
  },
  compilers: {
    solc: {
      version: "0.7.4",
    }
  }
};