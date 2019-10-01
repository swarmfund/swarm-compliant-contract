const SRC20Registry = artifacts.require('SRC20Registry');
const AssetRegistry = artifacts.require('AssetRegistry');
const SWMPriceOracle = artifacts.require('SWMPriceOracle');
const SelfServiceMinter = artifacts.require('SelfServiceMinter');

module.exports = function (deployer) {
    return SRC20Registry.deployed().then(async SRC20Registry => {
        return AssetRegistry.deployed().then(async assetRegistry => {
            return SWMPriceOracle.deployed().then(async swmPriceOracle => {
                return deployer.deploy(SelfServiceMinter,
                    SRC20Registry.address,
                    assetRegistry.address,
                    swmPriceOracle.address
                ).then(async selfServiceMinter => {
                    await SRC20Registry.addMinter(selfServiceMinter.address);
                });
            });
        });
    });
};
