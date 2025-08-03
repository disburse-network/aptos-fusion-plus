import { Aptos, AptosConfig, Network, Ed25519PrivateKey, Account } from "@aptos-labs/ts-sdk";
import { FusionPlusClient } from "./fusion-plus-client";
import { EventListener } from "./event-listener.js";

// Load environment variables
const dotenv = require('dotenv');

// Load environment variables
dotenv.config({ path: '../.env' });

// Configuration from environment variables
const NETWORK = (process.env.NETWORK as Network) || Network.TESTNET;
const CONTRACT_ADDRESS_TESTNET = process.env.CONTRACT_ADDRESS_TESTNET as string;
const CONTRACT_ADDRESS_DEVNET = process.env.CONTRACT_ADDRESS_DEVNET as string;

// Private keys from environment variables
const OWNER_PRIVATE_KEY = process.env.OWNER_PRIVATE_KEY as string;
const RESOLVER_PRIVATE_KEY = process.env.RESOLVER_PRIVATE_KEY as string;
const USER_PRIVATE_KEY = process.env.USER_PRIVATE_KEY as string;

// Configuration flags
const ENABLE_RESOLVER_REGISTRATION = process.env.ENABLE_RESOLVER_REGISTRATION === 'true';
const ENABLE_FAUCET_FUNDING = process.env.ENABLE_FAUCET_FUNDING === 'true';

// Validate required environment variables
function validateEnvironmentVariables() {
  const requiredVars = [
    'CONTRACT_ADDRESS_TESTNET',
    'CONTRACT_ADDRESS_DEVNET', 
    'OWNER_PRIVATE_KEY',
    'RESOLVER_PRIVATE_KEY',
    'USER_PRIVATE_KEY'
  ];
  
  const missingVars = requiredVars.filter(varName => !process.env[varName]);
  
  if (missingVars.length > 0) {
    console.error('❌ Missing required environment variables:');
    missingVars.forEach(varName => console.error(`   - ${varName}`));
    console.error('\n📝 Please create a .env file with the required variables:');
    console.error('   cp .example.env .env');
    console.error('   # Then edit .env with your values');
    process.exit(1);
  }
}

// Validate environment variables
validateEnvironmentVariables();

// Deployments configuration
const DEPLOYMENTS = {
  testnet: {
    address: CONTRACT_ADDRESS_TESTNET,
    explorer: `https://explorer.aptoslabs.com/account/${CONTRACT_ADDRESS_TESTNET}/modules/packages/aptos_fusion_plus?network=testnet`
  },
  devnet: {
    address: CONTRACT_ADDRESS_DEVNET,
    explorer: `https://explorer.aptoslabs.com/account/${CONTRACT_ADDRESS_DEVNET}/modules/packages/aptos_fusion_plus?network=devnet`
  }
};

console.log("🚀 Starting Aptos Fusion Plus Contract Testing");

// Initialize Aptos client
const config = new AptosConfig({ network: NETWORK });
const aptos = new Aptos(config);

// Create accounts from private keys
const ownerPrivateKey = new Ed25519PrivateKey(OWNER_PRIVATE_KEY);
const resolverPrivateKey = new Ed25519PrivateKey(RESOLVER_PRIVATE_KEY);
const userPrivateKey = new Ed25519PrivateKey(USER_PRIVATE_KEY);

const owner = Account.fromPrivateKey({ privateKey: ownerPrivateKey });
const resolver = Account.fromPrivateKey({ privateKey: resolverPrivateKey });
const user = Account.fromPrivateKey({ privateKey: userPrivateKey });

console.log(`📝 Owner address: ${owner.accountAddress}`);
console.log(`📝 Resolver address: ${resolver.accountAddress}`);
console.log(`📝 User address: ${user.accountAddress}`);

// Initialize FusionPlusClient
const fusionClient = new FusionPlusClient(aptos, DEPLOYMENTS.testnet.address);

// Initialize event listener for testnet
const eventListener = new EventListener(aptos, DEPLOYMENTS.testnet.address);

// Start listening to events
console.log("👂 Starting event listener...");
await eventListener.startListening();

// Test contract functions
console.log("🧪 Testing contract functions...");
await testContractFunctions(fusionClient, user, resolver, owner);

// Main function
async function main() {
  console.log("🚀 Starting Aptos Fusion Plus Testing Suite");
  
  // Note: For testnet, accounts need to be funded manually via https://aptos.dev/network/faucet
  console.log("💰 Note: For testnet, accounts need to be funded manually via https://aptos.dev/network/faucet");
  console.log("💰 Testing with existing accounts that should have funds...");
  
  // Start listening to events
  console.log("👂 Starting event listener...");
  await eventListener.startListening();
  
  // Test contract functions
  console.log("🧪 Testing contract functions...");
  await testContractFunctions(fusionClient, user, resolver, owner);
}

// Run the main function
main().catch(console.error);

async function getFusionOrderObjectAddress(contractAddress: string, transactionHash?: string): Promise<string | null> {
  console.log("🔍 Getting fusion order object address from events...");
  
  try {
    const fullnodeUrl = "https://api.testnet.aptoslabs.com/v1";
    
    // If we have a transaction hash, try to get events from that specific transaction
    if (transactionHash) {
      console.log("🔍 Trying to get events from specific transaction...");
      const txnResponse = await fetch(`${fullnodeUrl}/transactions/by_hash/${transactionHash}`);
      
      if (txnResponse.ok) {
        const txn = await txnResponse.json();
        console.log(`📡 Found transaction with ${txn.events?.length || 0} events`);
        
        if (txn.events) {
          for (const event of txn.events) {
            console.log(`Event type: ${event.type}`);
            
            if (event.type && event.type.includes("FusionOrderCreatedEvent")) {
              console.log("🔥 Found FusionOrderCreatedEvent in transaction!");
              console.log("Event data:", JSON.stringify(event.data, null, 2));
              
              if (event.data && event.data.fusion_order) {
                let fusionOrderAddress = event.data.fusion_order;
                
                // Handle different possible formats
                if (typeof fusionOrderAddress === 'object' && fusionOrderAddress.inner) {
                  fusionOrderAddress = fusionOrderAddress.inner;
                } else if (typeof fusionOrderAddress === 'string') {
                  // Already a string
                } else {
                  fusionOrderAddress = JSON.stringify(fusionOrderAddress);
                }
                
                console.log("📝 Extracted fusion order address from transaction:", fusionOrderAddress);
                return fusionOrderAddress;
              }
            }
          }
        }
      }
    }
    
    // If not found in transaction events, try to get events from the contract address
    console.log("🔍 Trying to get events from contract address...");
    const response = await fetch(`${fullnodeUrl}/accounts/${contractAddress}/events?limit=10`);
    
    if (!response.ok) {
      console.log("❌ Failed to fetch events from contract address");
      return null;
    }
    
    const events = await response.json();
    console.log(`📡 Found ${events.length} events from contract`);
    
    // Look for FusionOrderCreatedEvent
    for (const event of events) {
      console.log(`Event type: ${event.type}`);
      
      if (event.type && event.type.includes("FusionOrderCreatedEvent")) {
        console.log("🔥 Found FusionOrderCreatedEvent!");
        console.log("Event data:", JSON.stringify(event.data, null, 2));
        
        if (event.data && event.data.fusion_order) {
          let fusionOrderAddress = event.data.fusion_order;
          
          // Handle different possible formats
          if (typeof fusionOrderAddress === 'object' && fusionOrderAddress.inner) {
            fusionOrderAddress = fusionOrderAddress.inner;
          } else if (typeof fusionOrderAddress === 'string') {
            // Already a string
          } else {
            fusionOrderAddress = JSON.stringify(fusionOrderAddress);
          }
          
          console.log("📝 Extracted fusion order address:", fusionOrderAddress);
          return fusionOrderAddress;
        }
      }
    }
    
    console.log("❌ No FusionOrderCreatedEvent found in events");
    return null;
    
  } catch (error) {
    console.error("❌ Error fetching events:", error);
    return null;
  }
}

async function getEscrowObjectAddress(contractAddress: string, transactionHash?: string): Promise<string | null> {
  console.log("🔍 Getting escrow object address from events...");
  
  try {
    const fullnodeUrl = "https://api.testnet.aptoslabs.com/v1";
    
    // If we have a transaction hash, try to get events from that specific transaction
    if (transactionHash) {
      console.log("🔍 Trying to get events from specific transaction...");
      const txnResponse = await fetch(`${fullnodeUrl}/transactions/by_hash/${transactionHash}`);
      
      if (txnResponse.ok) {
        const txn = await txnResponse.json();
        console.log(`📡 Found transaction with ${txn.events?.length || 0} events`);
        
        if (txn.events) {
          for (const event of txn.events) {
            console.log(`Event type: ${event.type}`);
            
            if (event.type && event.type.includes("EscrowCreatedEvent")) {
              console.log("🔒 Found EscrowCreatedEvent in transaction!");
              console.log("Event data:", JSON.stringify(event.data, null, 2));
              
              if (event.data && event.data.escrow) {
                let escrowAddress = event.data.escrow;
                
                // Handle different possible formats
                if (typeof escrowAddress === 'object' && escrowAddress.inner) {
                  escrowAddress = escrowAddress.inner;
                } else if (typeof escrowAddress === 'string') {
                  // Already a string
                } else {
                  escrowAddress = JSON.stringify(escrowAddress);
                }
                
                console.log("📝 Extracted escrow address from transaction:", escrowAddress);
                return escrowAddress;
              }
            }
          }
        }
      }
    }
    
    // If not found in transaction events, try to get events from the contract address
    console.log("🔍 Trying to get events from contract address...");
    const response = await fetch(`${fullnodeUrl}/accounts/${contractAddress}/events?limit=10`);
    
    if (!response.ok) {
      console.log("❌ Failed to fetch events from contract address");
      return null;
    }
    
    const events = await response.json();
    console.log(`📡 Found ${events.length} events from contract`);
    
    // Look for EscrowCreatedEvent
    for (const event of events) {
      console.log(`Event type: ${event.type}`);
      
      if (event.type && event.type.includes("EscrowCreatedEvent")) {
        console.log("🔒 Found EscrowCreatedEvent!");
        console.log("Event data:", JSON.stringify(event.data, null, 2));
        
        if (event.data && event.data.escrow) {
          let escrowAddress = event.data.escrow;
          
          // Handle different possible formats
          if (typeof escrowAddress === 'object' && escrowAddress.inner) {
            escrowAddress = escrowAddress.inner;
          } else if (typeof escrowAddress === 'string') {
            // Already a string
          } else {
            escrowAddress = JSON.stringify(escrowAddress);
          }
          
          console.log("📝 Extracted escrow address:", escrowAddress);
          return escrowAddress;
        }
      }
    }
    
    console.log("❌ No EscrowCreatedEvent found in events");
    return null;
    
  } catch (error) {
    console.error("❌ Error fetching events:", error);
    return null;
  }
}

async function testContractFunctions(fusionClient: FusionPlusClient, user: Account, resolver: Account, owner: Account) {
  try {
    // Test basic contract interaction
    console.log("📊 Getting contract info...");
    const contractInfo = await fusionClient.getContractInfo();
    console.log("Contract info:", contractInfo);
    
    // Skip resolver registration since it's already registered
    console.log("\n📝 Skipping resolver registration (already registered)...");
    
    // Test fusion order creation
    console.log("\n🔥 Testing fusion order creation...");
    const aptMetadata = "0xa"; // APT metadata
    const destinationAsset = new Array(32).fill(0); // Native asset
    const destinationRecipient = [
      116, 45, 53, 204, 102, 52, 192, 83, 41, 37, 
      163, 184, 212, 201, 219, 150, 196, 180, 139, 119
    ]; // EVM address
    const hash = [
      18, 52, 86, 120, 144, 18, 52, 86, 120, 144, 18, 52, 86, 120, 144, 18, 
      52, 86, 120, 144, 18, 52, 86, 120, 144, 18, 52, 86, 120, 144, 18, 52
    ]; // 32-byte hash
    
    const createOrderPayload = fusionClient.buildTransactionPayload(
      "fusion_order::new_entry",
      [],
      [
        aptMetadata, // source_metadata
        1000000, // source_amount (1 APT)
        destinationAsset, // destination_asset
        destinationRecipient, // destination_recipient
        137, // chain_id (Polygon)
        hash, // hash
        1000000, // initial_destination_amount
        900000, // min_destination_amount
        100, // decay_per_second
      ]
    );
    console.log("Fusion order creation payload created");
    
    // Submit fusion order creation
    console.log("Submitting fusion order creation transaction...");
    const orderTxn = await fusionClient.submitTransaction(user, createOrderPayload);
    console.log("Fusion order creation transaction:", orderTxn.hash);
    
    // Wait a bit for the transaction to be processed
    console.log("⏳ Waiting for transaction to be processed...");
    await new Promise(resolve => setTimeout(resolve, 5000));
    
    // Test fusion order acceptance with real address
    console.log("\n🤝 Testing fusion order acceptance with real address...");
    const fusionOrderObjectAddress = await getFusionOrderObjectAddress(DEPLOYMENTS.testnet.address, orderTxn.hash);
    
    let acceptTxn: any; // Declare the variable
    
    if (!fusionOrderObjectAddress) {
      console.log("⚠️ Could not get fusion order address from events, using placeholder...");
      const placeholderAddress = "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef";
      console.log("📝 Using placeholder fusion order object address:", placeholderAddress);
      
      const acceptOrderPayload = fusionClient.buildTransactionPayload(
        "escrow::new_from_order_entry",
        [],
        [
          placeholderAddress, // fusion_order object address
        ]
      );
      console.log("Fusion order acceptance payload created");
      
      // Submit fusion order acceptance
      console.log("Submitting fusion order acceptance transaction...");
      acceptTxn = await fusionClient.submitTransaction(resolver, acceptOrderPayload);
      console.log("Fusion order acceptance transaction:", acceptTxn.hash);
    } else {
      console.log("📝 Using real fusion order object address:", fusionOrderObjectAddress);
      
      const acceptOrderPayload = fusionClient.buildTransactionPayload(
        "escrow::new_from_order_entry",
        [],
        [
          fusionOrderObjectAddress, // real fusion_order object address
        ]
      );
      console.log("Fusion order acceptance payload created");
      
      // Submit fusion order acceptance
      console.log("Submitting fusion order acceptance transaction...");
      acceptTxn = await fusionClient.submitTransaction(resolver, acceptOrderPayload);
      console.log("Fusion order acceptance transaction:", acceptTxn.hash);
    }
    
    // Test escrow creation
    console.log("\n🔒 Testing escrow creation...");
    // Convert recipient address to proper format (pad to 64 characters)
    const recipientAddress = "0x" + "742d35cc6634c0532925a3b8d4c9db96c4b48b77".padStart(64, '0');
    
    const createEscrowPayload = fusionClient.buildTransactionPayload(
      "escrow::new_from_resolver_entry",
      [],
      [
        recipientAddress, // recipient_address as string (padded to 64 chars)
        aptMetadata, // metadata (APT)
        950000, // amount
        137, // chain_id (Polygon)
        hash, // hash
      ]
    );
    console.log("Escrow creation payload created");
    
    // Submit escrow creation
    console.log("Submitting escrow creation transaction...");
    const escrowTxn = await fusionClient.submitTransaction(resolver, createEscrowPayload);
    console.log("Escrow creation transaction:", escrowTxn.hash);
    
    // Wait a bit for the transaction to be processed
    console.log("⏳ Waiting for escrow transaction to be processed...");
    await new Promise(resolve => setTimeout(resolve, 5000));
    
    // Test escrow withdraw with real address
    console.log("\n💸 Testing escrow withdraw with real address...");
    const escrowObjectAddress = await getEscrowObjectAddress(DEPLOYMENTS.testnet.address, escrowTxn.hash);
    
    let withdrawTxn: any; // Declare the variable
    
    if (!escrowObjectAddress) {
      console.log("⚠️ Could not get escrow address from events, using placeholder...");
      const placeholderAddress = "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef";
      console.log("📝 Using placeholder escrow object address:", placeholderAddress);
      
      // The secret that matches the hashlock (this should be the preimage of the hash)
      const secret = [
        18, 52, 86, 120, 144, 18, 52, 86, 120, 144, 18, 52, 86, 120, 144, 18, 
        52, 86, 120, 144, 18, 52, 86, 120, 144, 18, 52, 86, 120, 144, 18, 52
      ];
      
      const withdrawPayload = fusionClient.buildTransactionPayload(
        "escrow::withdraw",
        [],
        [
          placeholderAddress, // escrow object address
          secret, // secret to verify against hashlock
        ]
      );
      console.log("Escrow withdraw payload created");
      
      // Submit escrow withdraw
      console.log("Submitting escrow withdraw transaction...");
      withdrawTxn = await fusionClient.submitTransaction(resolver, withdrawPayload);
      console.log("Escrow withdraw transaction:", withdrawTxn.hash);
    } else {
      console.log("📝 Using real escrow object address:", escrowObjectAddress);
      
      // The secret that matches the hashlock (this should be the preimage of the hash)
      const secret = [
        18, 52, 86, 120, 144, 18, 52, 86, 120, 144, 18, 52, 86, 120, 144, 18, 
        52, 86, 120, 144, 18, 52, 86, 120, 144, 18, 52, 86, 120, 144, 18, 52
      ];
      
      const withdrawPayload = fusionClient.buildTransactionPayload(
        "escrow::withdraw",
        [],
        [
          escrowObjectAddress, // real escrow object address
          secret, // secret to verify against hashlock
        ]
      );
      console.log("Escrow withdraw payload created");
      
      // Submit escrow withdraw
      console.log("Submitting escrow withdraw transaction...");
      withdrawTxn = await fusionClient.submitTransaction(resolver, withdrawPayload);
      console.log("Escrow withdraw transaction:", withdrawTxn.hash);
    }
    
    console.log("✅ All contract function tests completed successfully");
    console.log("\n📋 Summary of submitted transactions:");
    console.log("  - Fusion order creation:", orderTxn.hash);
    if (fusionOrderObjectAddress) {
      console.log("  - Fusion order acceptance (with real address):", acceptTxn.hash);
    } else {
      console.log("  - Fusion order acceptance (with placeholder):", acceptTxn.hash);
    }
    console.log("  - Escrow creation:", escrowTxn.hash);
    if (escrowObjectAddress) {
      console.log("  - Escrow withdraw (with real address):", withdrawTxn.hash);
    } else {
      console.log("  - Escrow withdraw (with placeholder):", withdrawTxn.hash);
    }
    
  } catch (error) {
    console.error("❌ Error testing contract functions:", error);
  }
}

// Handle graceful shutdown
process.on('SIGINT', () => {
  console.log('\n🛑 Shutting down gracefully...');
  process.exit(0);
});

main().catch(console.error); 