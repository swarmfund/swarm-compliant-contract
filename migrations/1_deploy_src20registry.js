require('dotenv').config({path: '../.env'});
const Registry = artifacts.require("SRC20Registry");
const MockToken = artifacts.require("SwarmTokenMock");

const {
  ERC20_SWM,
  DEVELOPMENT_SWM_TOKEN_OWNER,
  DEVELOPMENT_SWM_MAX_TOKEN_SUPPLY
} = process.env;

module.exports = function (deployer, network) {
  if (!network.includes('mainnet')) {
    return deployer.deploy(MockToken,
        DEVELOPMENT_SWM_TOKEN_OWNER,
        DEVELOPMENT_SWM_MAX_TOKEN_SUPPLY
    ).then(async function (token) {
      return deployer.deploy(Registry,
          token.address
      );
    });
  } else {
    deployer.deploy(Registry,
        ERC20_SWM
    );
  }
};
