import {hoistCmp} from '@xh/hoist/core';
import {grid} from '@xh/hoist/cmp/grid';
import {panel} from '@xh/hoist/desktop/cmp/panel';
import {SamplePanelModel} from './SampleModel';

export const SamplePanel = hoistCmp.factory({
    model: SamplePanelModel,
    render({model}) {
        return panel({
            title: 'Sample',
            items: [grid({model: model.gridModel})]
        });
    }
});
