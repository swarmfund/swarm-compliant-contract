const utils = artifacts.require('Utils');
const swarmPoweredFundraise = artifacts.require('SwarmPoweredFundraise');
const currencyRegistry = artifacts.require('CurrencyRegistry');

const {
    DAI_ERC20
} = process.env;

module.exports = function (deployer) {

    deployer.link(utils, swarmPoweredFundraise);

    return deployer.deploy(
        swarmPoweredFundraise,
            'TEST',  // string memory _label,
            DAI_ERC20,  // address _src20,
            currencyRegistry.address,  // address _currencyRegistry,
            0,  // uint256 _SRC20tokenSupply,
            0,  // uint256 _startDate,
            0,  // uint256 _endDate,
            0,  // uint256 _softCapBCY,
            0   // uint256 _hardCapBCY
        ).then(
        async swarmPoweredFundraise => {
        }
    )

};