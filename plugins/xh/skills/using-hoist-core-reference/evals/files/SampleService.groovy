package sample

import io.xh.hoist.BaseService
import io.xh.hoist.cache.Cache

class SampleService extends BaseService {

    Cache<String, Map> dataCache = new Cache(svc: this, expireTime: 60_000)

    Map fetchData(String id) {
        dataCache.getOrCreate(id) { -> loadData(id) }
    }

    private Map loadData(String id) {
        return [id: id, value: Math.random()]
    }
}
