// Mock XHR worker
class XHRWorker {
  postMessage() {}
  terminate() {}
}

// Mock the XHR worker module
export default {
  XHRWorker,
  createWorker: () => new XHRWorker(),
};
