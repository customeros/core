export const stageOptions = [
  { label: 'Target', value: 'target', icon: 'target-04' },
  { label: 'Education', value: 'education', icon: 'book-closed' },
  { label: 'Solution', value: 'solution', icon: 'lightbulb-02' },
  { label: 'Evaluation', value: 'evaluation', icon: 'clipboard-check' },
  { label: 'Ready to buy', value: 'ready_to_buy', icon: 'rocket-02' },
];

export const stageIcons = Object.fromEntries(stageOptions.map(s => [s.value, s.icon]));
