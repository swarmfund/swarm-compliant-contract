const Factory = artifacts.require("SRC20Factory");
const Registry = artifacts.require("SRC20Registry");

module.exports = function (deployer) {
    deployer.then(function () {
        return Registry.deployed().then(registry => {
            return deployer.deploy(Factory,
                registry.address
            ).then(async factory => {
                await registry.addFactory(factory.address);
            });
        });
    });
};
