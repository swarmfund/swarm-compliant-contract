const contributorRestrictions = artifacts.require('ContributorRestrictions');

const {
    DAI_ERC20
} = process.env;

module.exports = function (deployer) {

    return deployer.deploy(
        contributorRestrictions,
            DAI_ERC20, // fundraise address
        ).then(
        async contributorRestrictions => {
        }
    )

};