import {HoistModel, managed} from '@xh/hoist/core';
import {GridModel} from '@xh/hoist/cmp/grid';
import {bindable} from '@xh/hoist/mobx';

export class SamplePanelModel extends HoistModel {
    @managed gridModel: GridModel;
    @bindable accessor filterText: string = '';

    constructor() {
        super();
        this.gridModel = new GridModel({
            columns: [
                {field: 'name'},
                {field: 'value'}
            ]
        });
    }
}
