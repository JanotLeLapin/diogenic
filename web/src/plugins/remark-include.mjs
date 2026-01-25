import { visit } from 'unist-util-visit';
import fs from 'node:fs';
import path from 'node:path';
import { unified } from 'unified';
import remarkParse from 'remark-parse';

export function remarkInclude() {
  return (tree, file) => {
    visit(tree, (node, index, parent) => {
      if (node.type !== 'leafDirective' || node.name !== 'include') return;

      const filePath = node.attributes.file;
      if (!filePath) return;

      const currentFileDir = path.dirname(file.history[0]);
      const absolutePath = path.resolve(currentFileDir, filePath);

      if (!fs.existsSync(absolutePath))
        return;

      const fileContent = fs.readFileSync(absolutePath, 'utf-8');
      
      const processor = unified().use(remarkParse);
      const ast = processor.parse(fileContent);

      parent.children.splice(index, 1, ...ast.children);
    });
  };
}
