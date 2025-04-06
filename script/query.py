# Helper script to query the blockchain

import subprocess
import argparse
import sys
import json
from typing import List, Dict, Any
import ast
from pathlib import Path

class ChainReader:
    def __init__(self, environment: str = "local"):
        if environment not in ["local", "devnet", "testnet"]:
            raise ValueError(f"Invalid environment: {environment}. Must be one of: local, devnet, testnet")
        
        self.environment = environment

        # Load the config file
        config = self._load_config()
        self.config = config[self.environment]
        self.rpc_url = self.config["rpc_url"]
        self.contracts = self._load_contracts(self.config)
        self.addresses = self._load_addresses(self.config)

    def _load_config(self) -> Dict[str, Any]:
        """Load the config file"""
        with open(Path(__file__).parent / "deployed-contracts.json") as f:
            config = json.load(f)
        return config

    def _load_contracts(self, config: Dict[str, Any]) -> Dict[str, str]:
        """Load contract addresses for the specified environment from config file"""
        # Extract contract addresses for the specified environment
        contracts = {}
        
        # Add contract addresses
        for contract in config["contracts"]:
            contracts[contract["name"]] = contract["address"]
                
        return contracts

    def _load_addresses(self, config: Dict[str, Any]) -> Dict[str, str]:
        """Load named addresses for the specified environment from config file"""
        return config["addresses"]

    def _run_cast_command(self, args: List[str]) -> str:
        cmd = ["cast"] + args
        try:
            result = subprocess.run(cmd, capture_output=True, text=True, check=True)
            return result.stdout.strip()
        except subprocess.CalledProcessError as e:
            print(f"Error running command: {' '.join(cmd)}")
            print(f"Error output: {e.stderr}")
            sys.exit(1)

    def _preprocess_tuple_string(self, tuple_str: str) -> str:
        """Add quotes around hex addresses in tuple string and normalize boolean values"""
        import re
        # Find all hex addresses (0x followed by 40 hex chars) and wrap them in quotes
        processed = re.sub(r'(0x[a-fA-F0-9]{40})', r'"\1"', tuple_str)
        # Convert JavaScript boolean strings to Python format
        return processed.replace("true", "True").replace("false", "False")

    def _parse_node_data(self, node_tuple: str) -> Dict[str, Any]:
        """Parse ComputeNode tuple into a dictionary"""
        # Convert string tuple to Python tuple using ast.literal_eval
        try:
            processed_tuple = self._preprocess_tuple_string(node_tuple)
            node_data = ast.literal_eval(processed_tuple)
            return {
                "provider": node_data[0],
                "subkey": node_data[1],
                "specsURI": node_data[2],
                "computeUnits": node_data[3],
                "benchmarkScore": node_data[4],
                "isActive": node_data[5],
                "isValidated": node_data[6]
            }
        except (ValueError, SyntaxError) as e:
            print(f"Error parsing node data: {e}")
            sys.exit(1)

    def _parse_provider_data(self, provider_tuple: str) -> Dict[str, Any]:
        """Parse ComputeProvider tuple into a dictionary"""
        try:
            processed_tuple = self._preprocess_tuple_string(provider_tuple)
            provider_data = ast.literal_eval(processed_tuple)
            nodes = [
                {
                    "provider": node[0],
                    "subkey": node[1],
                    "specsURI": node[2],
                    "computeUnits": node[3],
                    "benchmarkScore": node[4],
                    "isActive": node[5],
                    "isValidated": node[6]
                }
                for node in provider_data[3]
            ]
            return {
                "providerAddress": provider_data[0],
                "isWhitelisted": provider_data[1],
                "activeNodes": provider_data[2],
                "nodes": nodes
            }
        except (ValueError, SyntaxError) as e:
            print(f"Error parsing provider data: {e}")
            sys.exit(1)

    def _get_known_address(self, address: str) -> str:
        """Check if address matches any known contract/address and return the actual address"""
        # Convert to lowercase for case-insensitive comparison
        address_lower = address.lower()
        for name, known_address in self.addresses.items():
            if name.lower() == address_lower:
                return known_address
        return address

    def get_eth_balance(self, address: str) -> str:
        address = self._get_known_address(address)
        args = [
            "balance",
            "--rpc-url", self.rpc_url,
            address,
            "--ether"
        ]
        return self._run_cast_command(args)

    def get_ai_token_balance(self, address: str) -> str:
        address = self._get_known_address(address)
        args = [
            "call",
            "--rpc-url", self.rpc_url,
            self.contracts["ai_token"],
            "balanceOf(address)(uint256)",
            address
        ]
        return self._run_cast_command(args)

    def get_stake_minimum(self) -> str:
        args = [
            "call",
            "--rpc-url", self.rpc_url,
            self.contracts["stake_manager"],
            "getStakeMinimum()(uint256)"
        ]
        return self._run_cast_command(args)

    def get_stake(self, address: str) -> str:
        address = self._get_known_address(address)
        args = [
            "call",
            "--rpc-url", self.rpc_url,
            self.contracts["stake_manager"],
            "getStake(address)(uint256)",
            address
        ]
        return self._run_cast_command(args)
    
    def _get_reward_distributor(self, pool_id: str) -> str:
        args = [
            "call",
            "--rpc-url", self.rpc_url,
            self.contracts["compute_pool"],
            "getRewardDistributorForPool(uint256)(address)",
            pool_id,
            "--json"
        ]
        result = self._run_cast_command(args)
        # parse with json
        return json.loads(result)[0]


    def calculate_rewards(self, pool_id: str, node_subkey: str) -> str:
        reward_distributor = self._get_reward_distributor(pool_id)

        args = [
            "call",
            "--rpc-url", self.rpc_url,
            reward_distributor,
            "calculateRewards(address)(uint256,uint256)",
            node_subkey
        ]
        return self._run_cast_command(args)

    def get_reward_rate(self, pool_id: str) -> str:
        reward_distributor = self._get_reward_distributor(pool_id)
        args = [
            "call",
            "--rpc-url", self.rpc_url,
            reward_distributor,
            "getRewardRate()(uint256)"
        ]
        return self._run_cast_command(args)

    def get_whitelist_status(self, address: str) -> str:
        address = self._get_known_address(address)
        args = [
            "call",
            "--rpc-url", self.rpc_url,
            self.contracts["compute_registry"],
            "getWhitelistStatus(address)(bool)",
            address
        ]
        return self._run_cast_command(args)

    def get_node(self, node_subkey: str) -> str:
        node_subkey = self._get_known_address(node_subkey)
        args = [
            "call",
            "--rpc-url", self.rpc_url,
            self.contracts["compute_registry"],
            "getNode(address)((address,address,string,uint32,uint32,bool,bool))",
            node_subkey
        ]
        result = self._run_cast_command(args)
        return json.dumps(self._parse_node_data(result), indent=2)

    def get_provider(self, address: str) -> str:
        address = self._get_known_address(address)
        args = [
            "call",
            "--rpc-url", self.rpc_url,
            self.contracts["compute_registry"],
            "getProvider(address)((address,bool,uint32,(address,address,string,uint32,uint32,bool,bool)[]))",
            address
        ]
        result = self._run_cast_command(args)
        return json.dumps(self._parse_provider_data(result), indent=2)

    def get_node_validation_status(self, provider_address: str, node_subkey: str) -> str:
        provider_address = self._get_known_address(provider_address)
        node_subkey = self._get_known_address(node_subkey)
        args = [
            "call",
            "--rpc-url", self.rpc_url,
            self.contracts["compute_registry"],
            "getNodeValidationStatus(address,address)(bool)",
            provider_address,
            node_subkey
        ]
        return self._run_cast_command(args)

    def get_compute_pool_providers(self, pool_id: str = "1") -> str:
        args = [
            "call",
            "--rpc-url", self.rpc_url,
            self.contracts["compute_pool"],
            "getComputePoolProviders(uint256)(address[])",
            pool_id
        ]
        return self._run_cast_command(args)

    def get_compute_pool_nodes(self, pool_id: str = "1") -> str:
        args = [
            "call",
            "--rpc-url", self.rpc_url,
            self.contracts["compute_pool"],
            "getComputePoolNodes(uint256)(address[])",
            pool_id
        ]
        return self._run_cast_command(args)

    def list_known_addresses(self) -> str:
        """List all known contract addresses and named addresses for the current environment"""
        result = ["Known addresses for environment: " + self.environment]
        
        # Sort and format contract addresses
        for name, address in sorted(self.addresses.items()):
            result.append(f"  {name}: {address}")
            
        return "\n".join(result)

def get_command_help() -> str:
    """Returns formatted help string for all commands"""
    help_text = {
        'eth_balance': '<address>\n    Get ETH balance for address',
        'ai_balance': '<address>\n    Get AI token balance for address',
        'stake_minimum': '\n    Get minimum stake required',
        'stake': '<address>\n    Get stake for address',
        'rewards': '<node_subkey>\n    Calculate rewards for node',
        'reward_rate': '\n    Get current reward rate',
        'whitelist': '<address>\n    Check whitelist status for address',
        'provider': '<address>\n    Get provider details',
        'node': '<node_subkey>\n    Get node details',
        'node_validation': '<provider_address> <node_subkey>\n    Get node validation status',
        'active_providers': '[pool_id=1]\n    Get compute pool active providers',
        'active_nodes': '[pool_id=1]\n    Get compute pool active nodes',
        'list_addresses': '\n    List all known addresses for current environment'
    }
    
    return '\nAvailable commands:\n' + '\n'.join(
        f"  {cmd} {desc}\n" for cmd, desc in help_text.items()
    )

def main():
    parser = argparse.ArgumentParser(
        description='Query blockchain data using cast commands',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=get_command_help()
    )
    parser.add_argument('command', help='Command to execute')
    parser.add_argument('args', nargs='*', help='Arguments for the command')
    parser.add_argument('--env', '-e', 
                      choices=['local', 'devnet', 'testnet'],
                      default='local',
                      help='Environment to use (default: local)')

    args = parser.parse_args()
    chain_reader = ChainReader(environment=args.env)

    # Map command strings to methods
    commands = {
        'eth_balance': chain_reader.get_eth_balance,
        'ai_balance': chain_reader.get_ai_token_balance,
        'stake_minimum': chain_reader.get_stake_minimum,
        'stake': chain_reader.get_stake,
        'rewards': chain_reader.calculate_rewards,
        'reward_rate': chain_reader.get_reward_rate,
        'whitelist': chain_reader.get_whitelist_status,
        'provider': chain_reader.get_provider,
        'node': chain_reader.get_node,
        'node_validation': chain_reader.get_node_validation_status,
        'active_providers': chain_reader.get_compute_pool_providers,
        'active_nodes': chain_reader.get_compute_pool_nodes,
        'list_addresses': chain_reader.list_known_addresses
    }

    if args.command not in commands:
        print(f"Unknown command: {args.command}")
        print("Available commands:", ", ".join(commands.keys()))
        sys.exit(1)

    # Get the function for the command
    func = commands[args.command]
    
    # Call the function with any provided arguments
    try:
        result = func(*args.args)
        print(result)
    except TypeError:
        print(f"Error: Invalid number of arguments for command '{args.command}'")
        print(f"Usage: python read_chain.py {args.command} [args...]")
        sys.exit(1)

if __name__ == "__main__":
    main()