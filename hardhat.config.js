require('@nomiclabs/hardhat-waffle');
const MNEMONIC = "audit code attack vault avoid trap solve puzzle win trophy eternal glory";

module.exports = {
  solidity: {
    compilers: [
      {
        version: '0.8.28',
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
          viaIR: true
        },
      },
    ],
  },
  networks: {
    hardhat: {
      allowBlocksWithSameTimestamp: true,
      loggingEnabled: true,
      allowUnlimitedContractSize: true,
      blockGasLimit: 200000000,
      gas: 100000000, 
      gasPrice: 1000000000,
      initialBaseFeePerGas: 0,
      initialDate: "2025-01-01T00:00:00Z", // Fixed initial timestamp for determinism
      accounts: {
        mnemonic: MNEMONIC,
        path: "m/44'/60'/0'/0",
        initialIndex: 0,
        count: 20,
      }
    },
    localhost: {
      url: 'http://127.0.0.1:8545',
      timeout: 60000,
      gas: 100000000,
      accounts: {
        mnemonic: MNEMONIC,
        path: "m/44'/60'/0'/0",
        initialIndex: 0,
        count: 20,
      }
    },
  },
};
