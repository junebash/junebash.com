+++
title = "Swift Tarot MCP"
description = "Model Context Protocol server for tarot card readings, providing reliable randomness for AI assistants"
weight = 98

[extra]
source = "https://github.com/junebash/swift-tarot-mcp"
features = [
    "Full 78-card traditional tarot deck",
    "Single and multi-card readings", 
    "Deterministic testing with seeded RNG",
    "Comprehensive input validation",
    "Swift 5.9 with macOS 13.0+ support"
]
+++

**Swift Tarot MCP** is a Model Context Protocol server that enables AI assistants and other programs to perform tarot card readings with reliable randomness. Built to address the problem of poor randomness in Large Language Models, this server provides proper random number generation for personal tarot readings.

This project evolved from my earlier [**WhatTarotCLI**](https://github.com/junebash/WhatTarotCLI) tool, expanding the concept into a full MCP server. It supports both single card draws and multi-card spreads up to the full 78 cards of the traditional Rider-Waite-Smith tarot deck. It includes comprehensive tests and robust input validation, making it a reliable tool for integrating tarot functionality into AI workflows.
