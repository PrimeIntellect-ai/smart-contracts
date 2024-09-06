// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "./IVaultFactory.sol";

// Updated Vault Contract
contract Vault is IVault, Ownable, ERC4626, IERC1271 {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;
    using ECDSA for bytes32;

    mapping(address => uint256) public tokenBalances;
    mapping(address => uint256) public shareHolder;
    //  mapping(address => uint256) public tokenBudgets;

    IERC20 public token;
    uint256 public totalShares;
    mapping(address => uint256) public shares;
    ComputeProviderManager public computeProviderManager;

    event Deposit(address indexed user, uint256 amount, uint256 shares);
    event Withdraw(address indexed user, uint256 amount, uint256 shares);

    constructor(
        address _primeToken,
        address _owner,
        address _computeProviderManager
    ) {
        primeToken = IERC20(_primeToken);
        computeProviderManager = ComputeProviderManager(
            _computeProviderManager
        );
        transferOwnership(_owner);
    }

    function deposit(uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0");
        uint256 totalPrimeTokens = primeToken.balanceOf(address(this));
        uint256 sharesToMint;

        if (totalShares == 0 || totalPrimeTokens == 0) {
            sharesToMint = amount;
        } else {
            sharesToMint = amount.mul(totalShares).div(totalPrimeTokens);
        }

        primeToken.safeTransferFrom(msg.sender, address(this), amount);
        totalShares = totalShares.add(sharesToMint);
        shares[msg.sender] = shares[msg.sender].add(sharesToMint);

        emit Deposit(msg.sender, amount, sharesToMint);
    }

    function withdraw(uint256 shareAmount) external {
        require(shareAmount > 0, "Share amount must be greater than 0");
        require(shares[msg.sender] >= shareAmount, "Insufficient shares");

        uint256 totalPrimeTokens = primeToken.balanceOf(address(this));
        uint256 primeTokensToWithdraw = shareAmount.mul(totalPrimeTokens).div(
            totalShares
        );

        totalShares = totalShares.sub(shareAmount);
        shares[msg.sender] = shares[msg.sender].sub(shareAmount);

        primeToken.safeTransfer(msg.sender, primeTokensToWithdraw);

        emit Withdraw(msg.sender, primeTokensToWithdraw, shareAmount);
    }

    function approveComputeProvider(
        address computeProvider,
        uint256 amount
    ) external onlyOwner {
        require(
            computeProviderManager.isComputeProviderWhitelisted(
                computeProvider
            ),
            "Compute provider not whitelisted"
        );
        primeToken.safeApprove(computeProvider, amount);
    }

    /**
     * @notice isValidSignature returns whether the provider signature and hash are valid.
     */
    function isValidSignature(
        bytes32 hash,
        bytes memory signature
    ) external view override returns (bytes4) {
        address signer = ECDSA.recover(hash, signature);
        if (signer == owner()) {
            return 0x1626ba7e; // Magic value for ERC1271
        } else {
            return 0xffffffff; // Invalid signature
        }
    }
}
