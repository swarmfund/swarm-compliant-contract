const utils = artifacts.require('Utils');

module.exports = function (deployer) {

    return deployer.deploy(
        utils
        ).then(
        async utils => {
        }
    )

};