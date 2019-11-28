const affiliateManager = artifacts.require('affiliateManager');

const {
    AFFILIATE_ADDRESS,
    AFFILIATE_LINK,
    AFFILIATE_PERCENTAGE
} = process.env;

module.exports = function (deployer) {

    return deployer.deploy(
        affiliateManager
        ).then(
        async affiliateManager => {
            // Set up one affiliate
            await affiliateManager.setupAffiliate(
                AFFILIATE_ADDRESS,
                AFFILIATE_LINK,
                AFFILIATE_PERCENTAGE
            )
        }
    )

};