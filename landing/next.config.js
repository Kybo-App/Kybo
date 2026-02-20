/** @type {import('next').NextConfig} */
const nextConfig = {
  output: 'export',
  trailingSlash: true,
  reactStrictMode: true,
  transpilePackages: ['three'],
  images: {
    unoptimized: true, // required for static export (output: 'export')
  },
}

module.exports = nextConfig
