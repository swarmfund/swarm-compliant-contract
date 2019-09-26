const Featured = artifacts.require('Featured');
const SRC20Registry = artifacts.require('SRC20Registry');
const SRC20Roles = artifacts.require('SRC20Roles');
const TransferRules = artifacts.require('TransferRules');
const SRC20Factory = artifacts.require("SRC20Factory");

const {
    SRC20_FEATURES,
    TOKEN_OWNER,
    DEVELOPMENT_SWM_TOKEN_OWNER,
    NAME,
    SYMBOL,
    DECIMALS,
    KYA_HASH,
    KYA_URL,
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
                    return SRC20Factory.deployed().then(async SRC20Factory => {
                        const tx = await SRC20Factory.create(
                            TOKEN_OWNER,
                            NAME,
                            SYMBOL,
                            DECIMALS,
                            KYA_HASH,
                            KYA_URL,
                            rules.address,
                            roles.address,
                            featured.address
                        );

                        console.log('SRC20 contract address: ', tx.logs[2].args.token);
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
                    return SRC20Factory.deployed().then(async SRC20Factory => {
                        const tx = await SRC20Factory.create(
                            DEVELOPMENT_SWM_TOKEN_OWNER,
                            NAME,
                            SYMBOL,
                            DECIMALS,
                            KYA_HASH,
                            KYA_URL,
                            rules.address,
                            rules.address,
                            roles.address,
                            featured.address
                        );

                        console.log('SRC20 contract address: ', tx.logs[2].args.token);
                    });
                });
            });
        });
    }
};