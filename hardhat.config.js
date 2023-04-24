require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-etherscan");
require("hardhat-watcher");
require("hardhat-gas-reporter");
require('solidity-coverage');
require('@openzeppelin/hardhat-upgrades');
require('hardhat-storage-layout');
require('hardhat-contract-sizer');

const { alchemyApiKey, privateKey, etherscanApiKey, arbiscanApiKey, coinmarketcapKey } = require('./secrets.json');

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: "0.8.10",
  settings: {
    optimizer: {
      enabled: true,
      runs: 1,
    }
  },
  networks: {
    kovan: {
      url: `https://eth-kovan.alchemyapi.io/v2/${alchemyApiKey}`,
      accounts: [privateKey],
    },
    goerli: {
      url: `https://eth-goerli.g.alchemy.com/v2/${alchemyApiKey}`,
      accounts: [privateKey]
    },
    arbitrumtest: {
      url: "https://rinkeby.arbitrum.io/rpc",
      accounts: [privateKey],
    },
    arbgoerli: {
      url: "https://goerli-rollup.arbitrum.io/rpc",
      accounts: [privateKey],
    },
    arbitrumOne: {
      url: `https://arb-mainnet.g.alchemy.com/v2/${alchemyApiKey}`,
      accounts: [privateKey],
    },
    hardhat: {
      initialBaseFeePerGas: 0, // hack needed to make solidity-coverage work on LONDON
      forking: {
        url: `https://arb-mainnet.g.alchemy.com/v2/${alchemyApiKey}`
      }
    },
    localhost: {
      url: "http://localhost:8545",
      accounts: [privateKey],
    }
  },
  etherscan: {
    apiKey: {
      mainnet: `${etherscanApiKey}`,
      arbitrumOne: `${arbiscanApiKey}`,
      arbgoerli: `${arbiscanApiKey}`,
      arbitrumTestnet: `${arbiscanApiKey}`,
      goerli: `${etherscanApiKey}`
    },
    customChains: [
      {
        network: "arbgoerli",
        chainId: 421613,
        urls: {
          apiURL: "https://api-goerli.arbiscan.io//api",
          browserURL: "https://goerli.arbiscan.io"
        }
      }
    ]  
  },
  watcher: {
    test: {
      tasks: [{ command: 'test', params: { testFiles: ['{path}'] } }],
      files: ['./test/**/*'],
      verbose: true
    }
  },
  gasReporter: {
    currency: 'USD',
    coinmarketcap: `${coinmarketcapKey}`,
    enabled: (process.env.REPORT_GAS) ? true : false
  }
};
