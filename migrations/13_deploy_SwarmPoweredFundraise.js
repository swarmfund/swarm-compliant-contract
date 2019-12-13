const utils = artifacts.require('Utils');
const swarmPoweredFundraise = artifacts.require('SwarmPoweredFundraise');
const currencyRegistry = artifacts.require('CurrencyRegistry');

const {
    ZERO_ADDRESS,
    SRC20_ADDRESS,
    FUNDRAISE_LABEL,
    SRC20TOKEN_SUPPLY,
    START_DATE,
    END_DATE,
    SOFTCAP_BCY,
    HARDCAP_BCY
} = process.env;

module.exports = function (deployer) {

    deployer.link(utils, swarmPoweredFundraise);

    return deployer.deploy(
        swarmPoweredFundraise,
            FUNDRAISE_LABEL,
            SRC20_ADDRESS, // ZERO_ADDRESS
            currencyRegistry.address,
            SRC20TOKEN_SUPPLY,
            START_DATE,
            END_DATE,
            SOFTCAP_BCY,
            HARDCAP_BCY
        ).then(
        async swarmPoweredFundraise => {
        }
    )

};