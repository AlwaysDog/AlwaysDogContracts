require("@nomicfoundation/hardhat-toolbox");
require("@openzeppelin/hardhat-upgrades");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.22",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  networks: {
    // Add your network configurations here
    bscTestnet: {
      url: "https://data-seed-prebsc-1-s1.binance.org:8545",
      chainId: 97,
      // Add your private key here for deployment
      // accounts: ['your-private-key']
    },
    bsc: {
      url: "https://bsc-dataseed.binance.org/",
      chainId: 56,
      // Add your private key here for deployment
      // accounts: ['your-private-key']
    }
  }
};
