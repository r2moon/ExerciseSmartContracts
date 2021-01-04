const HDWalletProvider = require('@truffle/hdwallet-provider');
const keys = require("./key.json");

module.exports = {
  networks: {
    test: {
     host: "127.0.0.1",
     port: 8545,
     network_id: "*",
    },
    kovan: {
      provider: () => new HDWalletProvider(keys["kovan"]["privateKey"], keys["kovan"]["infura"]),
      network_id: 42,
      skipDryRun: true
    },
  },
  compilers: {
    solc: {
      version: "0.6.6",
      settings: {
       optimizer: {
         enabled: true,
         runs: 200
       }
      }
    }
  },
};
