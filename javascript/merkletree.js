console.log("Generating merkle");

const { StandardMerkleTree } = require("@openzeppelin/merkle-tree");

const inputs = [
    [ "0x7Ac410F4E36873022b57821D7a8EB3D7513C045a", 666 ],
    [ "0x2222222222222222222222222222222222222222", 123 ],
    [ "0x4762F7AcDFF1A245033e2C13B879acA14b71B2B5", 66 ],
    [ "0x58EA6e8e439caCaFBc99b1BFE2a4efdd4EBd0fC2", 55 ],
    [ "0x82cf634e280b5D6D2201d6393848fe301CAeBF9F", 44 ],
    [ "0x0c6F15f85e7f7831081A61DC310F432A958C844C", 22 ],
    [ "0xfec633035B92eF260f134a768C18aF11A311f713", 33 ],
    [ "0x80c5616AaF8683988559d3b69029D63DF986F7D8", 123 ],
    [ "0x04E77bA608Cc78aD8aEFfBc60a2Ea47ABdaEA7BA", 67 ],
    [ "0x8199d8342298CaF66Eb1a9050c8da8B66F91B23d", 67 ],
    [ "0xdd3DC2e72cEA2B2199FB4ECa7F367B4ACbC4FD90", 23 ],
    [ "0xbb47d887ba88631821A1708b35659EE9e4aCf02E", 55 ],
    [ "0x95954BA625a43f59bfEd2F63B8B8ce2cD8f23092", 1 ],
];

const tree = StandardMerkleTree.of(inputs, ["address", "uint256"]);

var dump = JSON.stringify(tree.dump());
console.log(dump);
let proof = undefined;

for (const [i, v] of tree.entries()) 
{
    if (v[0] === '0x7Ac410F4E36873022b57821D7a8EB3D7513C045a') 
    {
      proof = tree.getProof(i);
      console.log('I:', i);
      console.log('Proof:', proof);
    }
}
console.log("ROOT: "+tree.root);
console.log("LEAF "+tree.leafHash(0));