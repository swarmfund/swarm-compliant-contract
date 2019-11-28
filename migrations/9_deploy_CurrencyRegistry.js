const currencyRegistry = artifacts.require('CurrencyRegistry');

const {
    DAI_ERC20,
    DAI_EXCHANGE,
    USDC_ERC20,
    USDC_EXCHANGE,
    WBTC_ERC20,
    WBTC_EXCHANGE
} = process.env;

module.exports = function (deployer) {

    return deployer.deploy(
        currencyRegistry
        ).then(
        async currencyRegistry => {
            // ETH is auto-added at deployment, add the other three currencies we support
            await currencyRegistry.addCurrency(DAI_ERC20, DAI_EXCHANGE);
            await currencyRegistry.addCurrency(USDC_ERC20, USDC_EXCHANGE);
            await currencyRegistry.addCurrency(WBTC_ERC20, WBTC_EXCHANGE);
        }
    )

};