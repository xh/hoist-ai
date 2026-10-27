package sample

import io.xh.hoist.BaseController

class SampleController extends BaseController {

    SampleService sampleService

    def fetchData(String id) {
        renderJSON(sampleService.fetchData(id))
    }

    def listAll() {
        renderJSON([items: []])
    }
}
