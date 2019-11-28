const uniswapProxy = artifacts.require('UniswapProxy');

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
        uniswapProxy
        ).then(
        async uniswapProxy => {
            await uniswapProxy.addOrUpdateExchange(DAI_ERC20, DAI_EXCHANGE);
            await uniswapProxy.addOrUpdateExchange(USDC_ERC20, USDC_EXCHANGE);
            await uniswapProxy.addOrUpdateExchange(WBTC_ERC20, WBTC_EXCHANGE);
        }
    )

};