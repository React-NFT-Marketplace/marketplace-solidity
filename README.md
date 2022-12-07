# General Message Passing Tutorial

## Instructions

```sh
# copy .env
cp .env.example .env

# install dependencies
yarn

# 1st terminal: launch local cross-chain development
yarn local-dev:start

# compile contracts with hardhat
yarn contracts:build

# 2nd terminal: deploy contracts
yarn contracts:deploy

# start the ui
yarn dev

#DEBUG with
#hardhat list available network
npx hardhat verify --list-networks

#sample hardhat config
module.exports = {
  networks: {
    moonbaseAlpha: {
        url: `https://moonbase-alpha.public.blastapi.io`,
        accounts: ["b18ff97358de51ad123123e73asdasd1404as3ac8067cdf"],
    },
    avalancheFujiTestnet: {
        url: `https://avalanchetestapi.terminet.io/ext/bc/C/rpc`,
        accounts: ["b18f41231d246e8c0160c63525e32452304b3ed3ac8067cdf"],
    }
  },
  etherscan: {
    apiKey: {
        moonbaseAlpha: "9C4F28SZ8GX5EPGYX3Q9NRAC9ZJ26JD84X",
        avalancheFujiTestnet: "",
    }
  },
  solidity: {
    ...
  }
}

# Create arguments for contract constructor
# // arguments.js
module.exports = [
    "0x5769D84DD62a6fD969856c75c7D321b84d455929",
    "0xbE406F0189A0B4cf3A05C286473D23791Dd44Cc6"
];

# Execute verify contract
npx hardhat verify --constructor-args arguments.js --network moonbaseAlpha 0x9bAA0C52f2De8C611B76d7FAaC21C85371bFeb60

# Debug with tenderly
https://dashboard.tenderly.co/
```