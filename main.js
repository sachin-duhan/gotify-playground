const axios = require('axios');
const WebSocket = require('ws');

// Configuration
const GOTIFY_URL = 'http://localhost:8080';
const USERNAME = 'admin';
const PASSWORD = 'admin';

class GotifyTester {
    constructor() {
        this.clientToken = null;
        this.appToken = null;
        this.ws = null;
    }

    // Get client token for authentication
    async getClientToken() {
        try {
            const response = await axios.post(`${GOTIFY_URL}/client`, {
                name: 'Test Client'
            }, {
                auth: { username: USERNAME, password: PASSWORD }
            });
            this.clientToken = response.data.token;
            console.log('✅ Client token obtained:', this.clientToken);
            return this.clientToken;
        } catch (error) {
            console.error('❌ Failed to get client token:', error.response?.data || error.message);
        }
    }

    // Create application to send messages
    async createApplication() {
        try {
            const response = await axios.post(`${GOTIFY_URL}/application`, {
                name: 'Test App',
                description: 'Node.js test application'
            }, {
                auth: { username: USERNAME, password: PASSWORD }
            });
            this.appToken = response.data.token;
            console.log('✅ Application created with token:', this.appToken);
            return this.appToken;
        } catch (error) {
            console.error('❌ Failed to create application:', error.response?.data || error.message);
        }
    }

    // Send test message
    async sendMessage(title, message, priority = 5) {
        if (!this.appToken) {
            console.error('❌ No app token available. Create application first.');
            return;
        }

        try {
            const response = await axios.post(`${GOTIFY_URL}/message`, {
                title,
                message,
                priority
            }, {
                headers: {
                    'X-Gotify-Key': this.appToken
                }
            });
            console.log(`✅ Message sent: "${title}"`);
            return response.data;
        } catch (error) {
            console.error('❌ Failed to send message:', error.response?.data || error.message);
        }
    }

    // Connect to WebSocket for real-time messages
    connectWebSocket() {
        if (!this.clientToken) {
            console.error('❌ No client token available. Get client token first.');
            return;
        }

        const wsUrl = `ws://localhost:8080/stream?token=${this.clientToken}`;
        this.ws = new WebSocket(wsUrl);

        this.ws.on('open', () => {
            console.log('✅ WebSocket connected - listening for messages...');
        });

        this.ws.on('message', (data) => {
            const message = JSON.parse(data);
            console.log('📨 Received message:', {
                title: message.title,
                message: message.message,
                priority: message.priority,
                date: new Date(message.date)
            });
        });

        this.ws.on('error', (error) => {
            console.error('❌ WebSocket error:', error);
        });

        this.ws.on('close', () => {
            console.log('🔌 WebSocket disconnected');
        });
    }

    // Get all messages
    async getMessages() {
        try {
            const response = await axios.get(`${GOTIFY_URL}/message`, {
                auth: { username: USERNAME, password: PASSWORD }
            });
            console.log('📋 Messages:', response.data.messages.map(m => ({
                id: m.id,
                title: m.title,
                message: m.message,
                priority: m.priority,
                date: new Date(m.date)
            })));
            return response.data.messages;
        } catch (error) {
            console.error('❌ Failed to get messages:', error.response?.data || error.message);
        }
    }

    // Delete all messages
    async deleteAllMessages() {
        try {
            await axios.delete(`${GOTIFY_URL}/message`, {
                auth: { username: USERNAME, password: PASSWORD }
            });
            console.log('🗑️ All messages deleted');
        } catch (error) {
            console.error('❌ Failed to delete messages:', error.response?.data || error.message);
        }
    }

    // Run comprehensive test
    async runTest() {
        console.log('🚀 Starting Gotify test...\n');

        // Step 1: Get client token
        await this.getClientToken();
        
        // Step 2: Create application
        await this.createApplication();
        
        // Step 3: Connect WebSocket
        this.connectWebSocket();
        
        // Step 4: Send test messages
        await this.sendMessage('Test Message 1', 'This is a low priority test message', 1);
        await this.sendMessage('Test Message 2', 'This is a normal priority test message', 5);
        await this.sendMessage('Test Message 3', 'This is a high priority test message', 10);
        
        // Step 5: Wait a bit for WebSocket messages
        await new Promise(resolve => setTimeout(resolve, 2000));
        
        // Step 6: Get all messages
        await this.getMessages();
        
        // Step 7: Clean up
        setTimeout(() => {
            this.deleteAllMessages();
            if (this.ws) {
                this.ws.close();
            }
            console.log('\n✅ Test completed!');
            process.exit(0);
        }, 3000);
    }
}

// Run the test
const tester = new GotifyTester();
tester.runTest().catch(console.error);
