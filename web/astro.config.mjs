// @ts-check
import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';

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
