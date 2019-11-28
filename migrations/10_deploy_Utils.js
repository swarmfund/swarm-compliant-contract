const utils = artifacts.require('Utils');

const {
    AFFILIATE_ADDRESS,
    AFFILIATE_LINK,
    AFFILIATE_PERCENTAGE
} = process.env;

module.exports = function (deployer) {

    return deployer.deploy(
        utils
        ).then(
        async utils => {
            // await Utils.setupAffiliate(
            // )
        }
    )

};