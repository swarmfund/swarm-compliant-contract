const contributorRestrictions = artifacts.require('ContributorRestrictions');

const {
    DAI_ERC20,
    MAX_CONTRIBUTORS
} = process.env;

module.exports = function (deployer) {

    return deployer.deploy(
        contributorRestrictions,
            DAI_ERC20, // fundraise address
            MAX_CONTRIBUTORS // max number of contributors
        ).then(
        async contributorRestrictions => {
        }
    )

};