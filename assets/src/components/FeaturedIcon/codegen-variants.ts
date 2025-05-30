import fs from 'fs';
import { format } from 'prettier';

const prettierConfig = JSON.parse(fs.readFileSync(process.cwd() + '/.prettierrc', 'utf8'));
const colors = ['primary', 'gray', 'success', 'error'];

type compoundVariants = {
  colorScheme: string;
  className: string[];
}[];

const compoundVariants: compoundVariants = [];

colors.forEach(colorScheme => {
  const bgColor = `bg-${colorScheme}-100`;
  const ringColor = `ring-${colorScheme}-50`;
  const ringOffsetColor = `ring-offset-${colorScheme}-100`;
  const textColor = `text-${colorScheme}-600`;

  const className = [`${bgColor} ${ringColor} ${ringOffsetColor} ${textColor}`].filter(
    Boolean
  ) as string[];

  compoundVariants.push({
    colorScheme,
    className,
  });
});

const fileContent = `
import { cva } from 'class-variance-authority';

export const featureIconVariant = cva(
  ['flex', 'justify-center', 'items-center', 'rounded-full', 'overflow-visible'],
  {
    variants: {

      colorScheme: {
     primary: [],
     gray: [],
     success: [],
     error: [],
      },
    },
    compoundVariants: ${JSON.stringify(compoundVariants, null, 2)}
  },
);
`;

const formattedContent = format(fileContent, {
  ...prettierConfig,
  parser: 'babel',
});

const filePath = process.cwd() + '/src/components/FeaturedIcon/Icon.variants.ts';

formattedContent
  .then(content => {
    fs.writeFile(filePath, content, err => {
      if (err) {
        console.error('Error writing file:', err);
      } else {
        console.log('File written successfully');
      }
    });
  })
  .catch(err => {
    console.error('Error formatting content:', err);
  });
