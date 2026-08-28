import { describe, expect, it } from 'vitest';

import { buildWebSocketUrl } from './websocket';

describe('buildWebSocketUrl', () => {
  const params = new URLSearchParams({
    isolationKey: 'scriptAgent:12:project',
    projectId: '12',
    token: 'header.payload.signature',
  });

  it('uses an absolute API origin when development runs on another port', () => {
    expect(
      buildWebSocketUrl(
        'http://127.0.0.1:18080',
        '/socket/scriptAgent',
        params,
        'http://127.0.0.1:5666/projects/12',
      ),
    ).toBe(
      'ws://127.0.0.1:18080/socket/scriptAgent?isolationKey=scriptAgent%3A12%3Aproject&projectId=12&token=header.payload.signature',
    );
  });

  it('keeps a relative API prefix on the current browser origin', () => {
    expect(
      buildWebSocketUrl(
        '/api',
        '/socket/scriptAgent',
        params,
        'http://127.0.0.1:5666/projects/12',
      ),
    ).toBe(
      'ws://127.0.0.1:5666/api/socket/scriptAgent?isolationKey=scriptAgent%3A12%3Aproject&projectId=12&token=header.payload.signature',
    );
  });

  it('uses secure WebSockets for an HTTPS API base path', () => {
    expect(
      buildWebSocketUrl(
        'https://api.example.com/api/',
        'socket/productionAgent',
        params,
        'https://app.example.com/projects/12',
      ),
    ).toBe(
      'wss://api.example.com/api/socket/productionAgent?isolationKey=scriptAgent%3A12%3Aproject&projectId=12&token=header.payload.signature',
    );
  });
});
