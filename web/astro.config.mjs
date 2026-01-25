// @ts-check
import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';
import remarkDirective from 'remark-directive';
import { remarkInclude } from './src/plugins/remark-include.mjs';

import svelte from '@astrojs/svelte';

// https://astro.build/config
export default defineConfig({
    site: 'https://janotlelapin.github.io',
    base: '/diogenic/',
    markdown: {
        shikiConfig: {
            langAlias: {
                scm: 'lisp',
            },
            wrap: true,
        },
        remarkPlugins: [remarkDirective, remarkInclude],
    },
    integrations: [
        starlight({
            title: 'diogenic',
            social: [{ icon: 'github', label: 'GitHub', href: 'https://github.com/JanotLeLapin/diogenic' }],
            sidebar: [
                {
                    label: 'Guides',
                    items: [
                        { label: 'Introduction', slug: 'guides/intro' },
                    ],
                },
                {
                    label: 'Reference',
                    slug: 'reference',
                },
            ],
        }),
        svelte()
    ],
});
