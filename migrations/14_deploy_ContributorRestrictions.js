const contributorRestrictions = artifacts.require('ContributorRestrictions');
const swarmPoweredFundraise = artifacts.require('SwarmPoweredFundraise');

const {
    MAX_CONTRIBUTORS
} = process.env;

module.exports = function (deployer) {

    return deployer.deploy(
        contributorRestrictions,
            swarmPoweredFundraise.address,
            MAX_CONTRIBUTORS
        ).then(
        async contributorRestrictions => {
        }
    )

};