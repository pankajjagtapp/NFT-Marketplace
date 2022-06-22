const hre = require('hardhat');
const { BigNumber } = require('ethers');

async function main() {

	const JagguToken = await hre.ethers.getContractFactory('JagguToken');
	const totalSupply = BigNumber.from(10000000);
	const jagguToken = await JagguToken.deploy(totalSupply);
	console.log('Jaggu Token address: ', jagguToken.address);

	const NFTinstance = await hre.ethers.getContractFactory('NFT');
	const NFT = await NFTinstance.deploy();
	console.log('NFT address: ', NFT.address);

	const Marketplace = await hre.ethers.getContractFactory('Marketplace');
	const marketplace = await Marketplace.deploy(jagguToken.address);
	console.log('MarketPlace address: ', marketplace.address);
}

main()
	.then(() => process.exit(0))
	.catch((error) => {
		console.error(error);
		process.exit(1);
	});
