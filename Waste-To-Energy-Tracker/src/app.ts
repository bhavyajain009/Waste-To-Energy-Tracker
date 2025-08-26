// filepath: Waste-To-Energy-Tracker/src/app.ts
import express from 'express';

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware to parse JSON requests
app.use(express.json());

// Sample route for the Waste-To-Energy Tracker
app.get('/', (req, res) => {
    res.send('Welcome to the Waste-To-Energy Tracker API!');
});

// Start the server
app.listen(PORT, () => {
    console.log(`Server is running on http://localhost:${PORT}`);
});