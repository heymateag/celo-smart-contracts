module.exports = {
  networks: {
    // Test network
    test: {
      host: "127.0.0.1",
      port: 7545,
      network_id: "*"
    },
    // Celo Alfajores network
    alfajores: {
      host: "127.0.0.1",
      port: 8545,
      network_id: 44787
    }
  }
};