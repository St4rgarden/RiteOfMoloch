require("@nomiclabs/hardhat-waffle");
require("dotenv").config();
// The next line is part of the sample project, you don't need it in your
// project. It imports a Hardhat task definition, that can be used for
// testing the frontend.
require("./tasks/faucet");
const PRIVATE_KEY = process.env.PRIVATE_KEY;
const GNOSIS_RPC_URL = process.env.GNOSIS_RPC_URL;
// If you are using MetaMask, be sure to change the chainId to 1337
module.exports = {
  solidity: "0.8.4",
  networks: {
    hardhat: {
      forking: {
        //using pocket network as rpc endpoint for fork
        url: GNOSIS_RPC_URL,
        blockNumber: 22714454,
        chainId: 0x64,
      },
    },
  },
};
