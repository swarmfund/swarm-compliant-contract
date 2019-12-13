const currencyRegistry = artifacts.require('CurrencyRegistry');
const uniswapProxy = artifacts.require('UniswapProxy');

const {
    ZERO_ADDRESS,
    DAI_ERC20,
    USDC_ERC20,
    WBTC_ERC20
} = process.env;

module.exports = function (deployer) {

    return deployer.deploy(
        currencyRegistry
        ).then(
        async currencyRegistry => {
            await currencyRegistry.addCurrency(ZERO_ADDRESS, uniswapProxy.address);
            await currencyRegistry.addCurrency(DAI_ERC20, uniswapProxy.address);
            await currencyRegistry.addCurrency(USDC_ERC20, uniswapProxy.address);
            await currencyRegistry.addCurrency(WBTC_ERC20, uniswapProxy.address);
        }
    )

};