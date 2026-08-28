import echarts from './echarts';

let registration: Promise<void> | undefined;

/** Load the China geo data only for charts that explicitly need it. */
function registerChinaMap() {
  registration ??= import('./map/china.json').then(({ default: chinaMap }) => {
    echarts.registerMap('china', {
      geoJSON: chinaMap as any,
      specialAreas: {
        china: {
          height: 1000,
          left: 500,
          top: 500,
          width: 1000,
        },
      },
    });
  });
  return registration;
}

export { registerChinaMap };
