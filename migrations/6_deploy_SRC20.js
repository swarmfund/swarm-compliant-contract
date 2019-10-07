const Featured = artifacts.require('Featured');
const SRC20Registry = artifacts.require('SRC20Registry');
const SRC20Roles = artifacts.require('SRC20Roles');
const TransferRules = artifacts.require('TransferRules');
const SRC20Factory = artifacts.require("SRC20Factory");
const AssetRegistry = artifacts.require('AssetRegistry');
const SelfServiceMinter = artifacts.require('SelfServiceMinter');

const {
    SRC20_FEATURES,
    TOKEN_OWNER,
    DEVELOPMENT_SWM_TOKEN_OWNER,
    NAME,
    SYMBOL,
    DECIMALS,
    MAX_TOTAL_SUPPLY,
    KYA_HASH,
    KYA_URL,
    NET_ASSET_VALUE,
} = process.env;

module.exports = async function (deployer, network) {
    if (network.includes('mainnet')) {
        const registry = await SRC20Registry.deployed();

        return deployer.deploy(SRC20Roles,
            TOKEN_OWNER,
            registry.address,
        ).then(async function (roles) {
            return deployer.deploy(Featured,
                TOKEN_OWNER,
                SRC20_FEATURES
            ).then(async function (featured) {
                return deployer.deploy(TransferRules,
                    TOKEN_OWNER
                ).then(async function (rules) {
                    return AssetRegistry.deployed().then(async assetRegistry => {
                        return SelfServiceMinter.deployed().then(async selfServiceMinter => {
                            return SRC20Factory.deployed().then(async SRC20Factory => {
                                const tx = await SRC20Factory.create(
                                    NAME,
                                    SYMBOL,
                                    DECIMALS,
                                    MAX_TOTAL_SUPPLY,
                                    KYA_HASH,
                                    KYA_URL,
                                    NET_ASSET_VALUE,
                                    [
                                        TOKEN_OWNER,
                                        rules.address,
                                        rules.address,
                                        roles.address,
                                        featured.address,
                                        assetRegistry.address,
                                        selfServiceMinter.address
                                    ],
                                );

                                const src20Address = tx.logs[0].args.token;
                                console.log('SRC20 contract address: ', src20Address);
                            });
                        });
                    });
                });
            });
        });
    } else {
        const registry = await SRC20Registry.deployed();

        return deployer.deploy(SRC20Roles,
            DEVELOPMENT_SWM_TOKEN_OWNER,
            registry.address,
        ).then(async function (roles) {
            return deployer.deploy(Featured,
                DEVELOPMENT_SWM_TOKEN_OWNER,
                SRC20_FEATURES
            ).then(async function (featured) {
                return deployer.deploy(TransferRules,
                    TOKEN_OWNER
                ).then(async function (rules) {
                    return AssetRegistry.deployed().then(async assetRegistry => {
                        return SelfServiceMinter.deployed().then(async selfServiceMinter => {
                            return SRC20Factory.deployed().then(async SRC20Factory => {
                                const tx = await SRC20Factory.create(
                                    NAME,
                                    SYMBOL,
                                    DECIMALS,
                                    MAX_TOTAL_SUPPLY,
                                    KYA_HASH,
                                    KYA_URL,
                                    NET_ASSET_VALUE,
                                    [
                                        TOKEN_OWNER,
                                        rules.address,
                                        rules.address,
                                        roles.address,
                                        featured.address,
                                        assetRegistry.address,
                                        selfServiceMinter.address
                                    ],
                                );

                                const src20Address = tx.logs[0].args.token;
                                console.log('SRC20 contract address: ', src20Address);
                            });
                        });
                    });
                });
            });
        });
    }
};