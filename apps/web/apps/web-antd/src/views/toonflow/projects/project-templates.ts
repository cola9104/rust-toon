import type { ToonflowApi } from '#/api/toonflow';

export type ProjectTemplateKey = 'short_drama' | 'time_travel';

const STANDARD_DESCRIPTION = '按项目简介和剧本确定统一世界观。';
const STANDARD_LABEL = '标准剧场';

export const projectTemplateOptions = [
  {
    description: STANDARD_DESCRIPTION,
    label: STANDARD_LABEL,
    value: 'short_drama',
  },
  {
    description: '保留古今元素各自年代，并维持人物跨时代身份一致。',
    label: '穿越剧场',
    value: 'time_travel',
  },
];

export function createProjectDefaults(
  template: ProjectTemplateKey = 'short_drama',
): ToonflowApi.SaveProject {
  return {
    artStyle: '',
    chatModel: undefined,
    directorManual: '',
    imageModel: undefined,
    imageQuality: '2K',
    intro: '',
    mode: 'startEndRequired',
    name: '',
    projectType: template,
    type: template === 'time_travel' ? '穿越' : '短剧',
    videoModel: undefined,
    videoRatio: '16:9',
  };
}

export function projectTemplateDescription(projectType?: string) {
  return (
    projectTemplateOptions.find((item) => item.value === projectType)
      ?.description || STANDARD_DESCRIPTION
  );
}

export function projectTemplateLabel(projectType?: string) {
  return (
    projectTemplateOptions.find((item) => item.value === projectType)?.label ||
    STANDARD_LABEL
  );
}
