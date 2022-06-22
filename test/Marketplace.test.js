const { expect } = require('chai');
const { BigNumber } = require('ethers');
const { ethers } = require('hardhat');

describe('Marketplace Contract', function () {
	let jagguToken;
	let NFTContract;
	let marketplace;
	let tokenURI1;
	let tokenURI2;
	const platformFeePercent = 25;
	let addr1;
	let addr2;
	let addr3;
	let addrs;

	beforeEach(async () => {
		[manager, addr1, addr2, addr3, ...addrs] = await ethers.getSigners();

		// For ERC20 Tokens
		const JagguToken = await hre.ethers.getContractFactory('JagguToken');
		const totalSupply = BigNumber.from(10000000);
		jagguToken = await JagguToken.deploy(totalSupply);
		await jagguToken.deployed();

		// For NFTs
		const NFTinstance = await hre.ethers.getContractFactory('NFT');
		NFTContract = await NFTinstance.deploy();
		await NFTContract.deployed();
		tokenURI1 = "https://gateway.pinata.cloud/ipfs/QmZFkQt9kkBNbDqKVdSN5E3nscUnwBJ1dKcm6xUVz8r9VP"
		tokenURI2 = "https://gateway.pinata.cloud/ipfs/QmUu2mrYdZQgMxdjc58uwrxUhujSZbSfSgZHyXH1gPZBdv"
		
		// For Marketplace
		const Marketplace = await hre.ethers.getContractFactory('Marketplace');
		marketplace = await Marketplace.deploy(jagguToken.address);
		await marketplace.deployed();

		// Send Jaggu Tokens to 3 addresses
		await jagguToken.transfer(addr1.address, 100000);
		await jagguToken.transfer(addr2.address, 100000);
		await jagguToken.transfer(addr3.address, 100000);
	});

	describe('Deployment', async () => {
		it('Should return the correct name', async () => {
			expect(await jagguToken.name()).to.equal('JagguToken');
		});

		it("Should track adminAccount and feePercent of the marketplace", async () => {
			expect(await marketplace.adminAccount()).to.equal(manager.address);
			expect(await marketplace.platformFeePercent()).to.equal(platformFeePercent);
		});
	});

	describe('NFT Contract Tests', async () => {
        it("exclusively allows owners to list", async () => {
			await NFTContract.mint(tokenURI1)
			await NFTContract.mint(tokenURI2)
    		expect(await NFTContract.ownerOf(1)).to.equal(manager.address);
    		expect(await NFTContract.ownerOf(2)).to.equal(manager.address);
		})

		it("Should track minted NFT", async () => {
			
			// addr1 mints an NFT
			await NFTContract.connect(addr1).mint(tokenURI1)
			expect(await NFTContract.tokenCount()).to.equal(1);
			expect(await NFTContract.balanceOf(addr1.address)).to.equal(1);
			expect(await NFTContract.tokenURI(1)).to.equal(tokenURI1);
		  });
		});

	describe('Marketplace Tests', async () => {

		it('Should list NFT on the Marketplace', async () => {
			await NFTContract.connect(addr1).mint(tokenURI1)
			await NFTContract.connect(addr1).setApprovalForAll(marketplace.address, true)
    		await marketplace.connect(addr1).listItem(NFTContract.address, 1, 4000, 25)
			await NFTContract.connect(addr2).mint(tokenURI2)
			await NFTContract.connect(addr2).setApprovalForAll(marketplace.address, true)
    		await marketplace.connect(addr2).listItem(NFTContract.address, 2, 5000, 35)
		})

		it('Should cancel listing', async()=>{
			await expect(marketplace.cancelListing(1)).to.be.revertedWith('You are not the owner of the NFT item')
		})

		it("Should fail if price is zero", async () => {
			await NFTContract.connect(addr1).mint(tokenURI1)
			await NFTContract.connect(addr1).setApprovalForAll(marketplace.address, true)
			await expect(marketplace.connect(addr1).listItem(NFTContract.address, 1, 0, 35)).to.be.revertedWith("Price has to be greater than zero");
		  });
    });
});
