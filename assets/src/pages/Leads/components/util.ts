import { IconName } from 'src/components/Icon';

type StageOption = {
  label: string;
  value: string;
  icon: IconName;
};

export const stageOptions: StageOption[] = [
  { label: 'Target', value: 'target', icon: 'target-04' },
  { label: 'Education', value: 'education', icon: 'book-closed' },
  { label: 'Solution', value: 'solution', icon: 'lightbulb-02' },
  { label: 'Evaluation', value: 'evaluation', icon: 'clipboard-check' },
  { label: 'Ready to buy', value: 'ready_to_buy', icon: 'rocket-02' },
  { label: 'Customers', value: 'customer', icon: 'activity-heart' },
];

export const stageOptionsWithoutCustomer: StageOption[] = [
  { label: 'Target', value: 'target', icon: 'target-04' },
  { label: 'Education', value: 'education', icon: 'book-closed' },
  { label: 'Solution', value: 'solution', icon: 'lightbulb-02' },
  { label: 'Evaluation', value: 'evaluation', icon: 'clipboard-check' },
  { label: 'Ready to buy', value: 'ready_to_buy', icon: 'rocket-02' },
];

export const stageIcons = Object.fromEntries(stageOptions.map(s => [s.value, s.icon]));
