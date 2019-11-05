const SRC20Registry = artifacts.require('SRC20Registry');
const AssetRegistry = artifacts.require('AssetRegistry');
const SWMPriceOracle = artifacts.require('SWMPriceOracle');
const GetRateMinter = artifacts.require('GetRateMinter');
const SetRateMinter = artifacts.require('SetRateMinter');

module.exports = function (deployer) {
    return SRC20Registry.deployed().then(async SRC20Registry => {
        return AssetRegistry.deployed().then(async assetRegistry => {
            return SWMPriceOracle.deployed().then(async swmPriceOracle => {
                return deployer.deploy(GetRateMinter,
                    SRC20Registry.address,
                    assetRegistry.address,
                    swmPriceOracle.address
                ).then(async getRateMinter => {
                    await SRC20Registry.addMinter(getRateMinter.address);

                    return deployer.deploy(SetRateMinter,
                        SRC20Registry.address
                    ).then(async setRateMinter => {
                        await SRC20Registry.addMinter(setRateMinter.address);
                    })
                });
            });
        });
    });
};
