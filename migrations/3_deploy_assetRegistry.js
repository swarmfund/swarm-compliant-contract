const Factory = artifacts.require("SRC20Factory");
const AssetRegistry = artifacts.require("AssetRegistry");

module.exports = function (deployer) {
    return Factory.deployed().then(async factory => {
        return deployer.deploy(AssetRegistry, factory.address)
    });
};
