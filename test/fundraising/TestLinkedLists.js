const {BN, constants, expectEvent, shouldFail} = require('openzeppelin-test-helpers');
const crypto = require('crypto');
const moment = require('moment');
const helpers = require('../token/helpers');
const {encodeTransfer} = require('../token/utils');

const TestLinkedLists = artifacts.require('TestLinkedLists');

contract('SwarmPoweredFundraise', async function ([_, whitelistManager, authority, owner, issuer, contributor]) {

  beforeEach(async function () {

    this.testLinkedLists = await TestLinkedLists.new({from: owner});

    /*
    await this.testLinkedLists.register(100, 1200, {from:owner});
    await this.testLinkedLists.register(100, 9000, {from:issuer});
    await this.testLinkedLists.register(100, 1500, {from:contributor});
    await this.testLinkedLists.register(100, 850, {from:whitelistManager});
    await this.testLinkedLists.register(100, 1350, {from:authority});
    console.log('owner:', owner);
    console.log('issuer:', issuer);
    console.log('contributor:', contributor);
    console.log('whitelistManager:', whitelistManager);
    console.log('authority:', authority);
    console.log('providerCount:', await this.testLinkedLists.providerCount.call());
    console.log('List:', await this.testLinkedLists.getList());
    */
  });

  describe('Test adding to linked list', function () {

    it('should correctly add the first/head member', async function () {
        console.log('providerCount:', await this.testLinkedLists.providerCount.call());
        console.log('List:', await this.testLinkedLists.getList());
        await this.testLinkedLists.register(100, 1200, {from:owner});
        console.log('providerCount:', await this.testLinkedLists.providerCount.call());
        console.log('List:', await this.testLinkedLists.getList());
    });

    it('should correctly add a member that has smaller markup than head', async function () {
        await this.testLinkedLists.register(100, 1200, {from:owner});
        console.log('providerCount:', await this.testLinkedLists.providerCount.call());
        console.log('List:', await this.testLinkedLists.getList());

        await this.testLinkedLists.register(100, 900, {from:issuer});
        console.log('providerCount:', await this.testLinkedLists.providerCount.call());
        console.log('List:', await this.testLinkedLists.getList());
    });

    it('should correctly add a member that has same markup as head', async function () {
        await this.testLinkedLists.register(100, 1200, {from:owner});
        console.log('providerCount:', await this.testLinkedLists.providerCount.call());
        console.log('List:', await this.testLinkedLists.getList());

        await this.testLinkedLists.register(100, 1200, {from:issuer});
        console.log('providerCount:', await this.testLinkedLists.providerCount.call());
        console.log('List:', await this.testLinkedLists.getList());
      });

      it('should correctly add a member that has higher markup than head', async function () {
        await this.testLinkedLists.register(100, 1200, {from:owner});
        console.log('providerCount:', await this.testLinkedLists.providerCount.call());
        console.log('List:', await this.testLinkedLists.getList());

        await this.testLinkedLists.register(100, 1500, {from:issuer});
        console.log('providerCount:', await this.testLinkedLists.providerCount.call());
        console.log('List:', await this.testLinkedLists.getList());
      });

      it('should correctly add a member is not the first nor the last', async function () {

        await this.testLinkedLists.register(100, 1200, {from:owner});
        await this.testLinkedLists.register(100, 900, {from:issuer});
        console.log('providerCount:', await this.testLinkedLists.providerCount.call());
        console.log('List:', await this.testLinkedLists.getList());

        await this.testLinkedLists.register(100, 970, {from:contributor});
        console.log('providerCount:', await this.testLinkedLists.providerCount.call());
        console.log('List:', await this.testLinkedLists.getList());
      });

      it('should correctly add (that is, just update) a member that already exists as first, so it becomes last', async function () {
        await this.testLinkedLists.register(100, 900, {from:owner});
        await this.testLinkedLists.register(100, 1200, {from:issuer});
        console.log('providerCount:', await this.testLinkedLists.providerCount.call());
        console.log('List:', await this.testLinkedLists.getList());

        await this.testLinkedLists.register(100, 1500, {from:owner});
        console.log('providerCount:', await this.testLinkedLists.providerCount.call());
        console.log('List:', await this.testLinkedLists.getList());
      });

      it('should correctly add (that is, just update) a member that already exists as last, so it becomes first', async function () {
        await this.testLinkedLists.register(100, 900, {from:owner});
        await this.testLinkedLists.register(100, 1200, {from:issuer});
        console.log('providerCount:', await this.testLinkedLists.providerCount.call());
        console.log('List:', await this.testLinkedLists.getList());

        await this.testLinkedLists.register(100, 870, {from:issuer});
        console.log('providerCount:', await this.testLinkedLists.providerCount.call());
        console.log('List:', await this.testLinkedLists.getList());
      });

      it('should correctly add (that is, just update) a member that already exists in the middle, so it becomes first', async function () {
        await this.testLinkedLists.register(100, 900, {from:owner});
        await this.testLinkedLists.register(100, 1200, {from:issuer});
        await this.testLinkedLists.register(100, 1500, {from:contributor});
        console.log('providerCount:', await this.testLinkedLists.providerCount.call());
        console.log('List:', await this.testLinkedLists.getList());

        await this.testLinkedLists.register(100, 850, {from:issuer});
        console.log('providerCount:', await this.testLinkedLists.providerCount.call());
        console.log('List:', await this.testLinkedLists.getList());
      });

      it('should correctly add (that is, just update) a member that already exists in the middle, so it becomes last', async function () {
        await this.testLinkedLists.register(100, 900, {from:owner});
        await this.testLinkedLists.register(100, 1200, {from:issuer});
        await this.testLinkedLists.register(100, 1500, {from:contributor});
        console.log('providerCount:', await this.testLinkedLists.providerCount.call());
        console.log('List:', await this.testLinkedLists.getList());

        await this.testLinkedLists.register(100, 1600, {from:issuer});
        console.log('providerCount:', await this.testLinkedLists.providerCount.call());
        console.log('List:', await this.testLinkedLists.getList());
      });

      it('should correctly add (that is, just update) a member that is the head', async function () {
        await this.testLinkedLists.register(100, 1200, {from:owner});
        console.log('providerCount:', await this.testLinkedLists.providerCount.call());
        console.log('List:', await this.testLinkedLists.getList());

        await this.testLinkedLists.register(100, 9770, {from:owner});
        console.log('providerCount:', await this.testLinkedLists.providerCount.call());
        console.log('List:', await this.testLinkedLists.getList());
      });

  }); // describe

  describe('Test removing from linked list', function () {

      it('should correctly unregister a member that already exists in the middle', async function () {
        await this.testLinkedLists.register(100, 900, {from:owner});
        await this.testLinkedLists.register(100, 950, {from:issuer});
        await this.testLinkedLists.register(100, 970, {from:contributor});
        console.log('providerCount:', await this.testLinkedLists.providerCount.call());
        console.log('List:', await this.testLinkedLists.getList());

        await this.testLinkedLists.unRegister(issuer, {from:owner});

        console.log('providerCount:', await this.testLinkedLists.providerCount.call());
        console.log('List:', await this.testLinkedLists.getList());
      });

      it('should correctly unregister the first member', async function () {
        await this.testLinkedLists.register(100, 900, {from:owner});
        await this.testLinkedLists.register(100, 950, {from:issuer});
        await this.testLinkedLists.register(100, 970, {from:contributor});
        console.log('providerCount:', await this.testLinkedLists.providerCount.call());
        console.log('List:', await this.testLinkedLists.getList());

        await this.testLinkedLists.unRegister(owner, {from:owner});

        console.log('providerCount:', await this.testLinkedLists.providerCount.call());
        console.log('List:', await this.testLinkedLists.getList());
      });

      it('should correctly unregister the last member', async function () {
        await this.testLinkedLists.register(100, 900, {from:owner});
        await this.testLinkedLists.register(100, 950, {from:issuer});
        await this.testLinkedLists.register(100, 970, {from:contributor});
        console.log('providerCount:', await this.testLinkedLists.providerCount.call());
        console.log('List:', await this.testLinkedLists.getList());

        await this.testLinkedLists.unRegister(contributor, {from:owner});

        console.log('providerCount:', await this.testLinkedLists.providerCount.call());
        console.log('List:', await this.testLinkedLists.getList());
      });

      it('should correctly unregister a member that is the head', async function () {
        await this.testLinkedLists.register(100, 1200, {from:issuer});
        console.log('providerCount:', await this.testLinkedLists.providerCount.call());
        console.log('List:', await this.testLinkedLists.getList());

        await this.testLinkedLists.unRegister(issuer, {from:owner});

        console.log('providerCount:', await this.testLinkedLists.providerCount.call());
        console.log('List:', await this.testLinkedLists.getList());
      });

  }); // describe

});
