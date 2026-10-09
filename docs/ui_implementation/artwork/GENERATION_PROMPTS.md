# Built-in image generation prompt record

October 9, 2026. `image_gen__imagegen` was used, one call per asset. `transparent_background: true` for every persona/weather sprite, and `false` for the beach. Exact resumed-run prompts follow. Referenced images are listed in `asset_metadata.json`; Frat Bro, Politician and toddler also included the recovered Karen portrait as a style reference, and the sunglasses cloud included the generated hero as a style reference.

## Today hero

Use case: identity-preserve. Asset type: transparent illustration for DayMaker Flutter weather hero. Reconstruct ONLY the weather illustration in the supplied low resolution approved reference as a clean high resolution cutout, closely matching shapes, pose, colors and dimensional soft cartoon shading. A rounded white grumpy cloud with dark navy oval eyes, asymmetrical furrowed brows, tiny downturned mouth and pink cheeks sits in front of a golden yellow sun wearing dark navy sunglasses; five short rounded golden rays are visible. Pale lavender and blue shaded underside to cloud. Preserve exact relative size and overlap from reference. Transparent background, no sky/backdrop, no oval floor shadow, no text, no UI fragments, no black mark at left, no border. Crisp smooth clean alpha edge with no floating pixels or halo. Square canvas, subject centered fills about 90%, all rays fully inside canvas.

## Frat Bro

Use case: identity-preserve. Asset type: DayMaker persona portrait. Reconstruct the male Frat Bro character from image 1 as clean high resolution transparent bust. Image 1 is identity lock; image 2 only gives same approved soft dimensional cartoon illustration finish. Keep youthful warm fair skin, light brown hair under a light blue backward baseball cap, dark navy sunglasses, broad friendly overconfident smile, simple mustard yellow crewneck shirt. Same frontal face and round simplified features as tiny reference. Show head and shoulders only, no hands, no new props or outfit additions, no full body. Bust centered on portrait 3:4 canvas with entire cap and shoulders inside; subtle soft shading like reference, no photographic skin or texture. Actual transparent background, clean smooth alpha without halos/floating speckles, no rounded tile background, no text, no UI.

## Politician

Use case: identity-preserve. Asset type: DayMaker persona portrait. Reconstruct ONLY Politician from image 1 as high resolution transparent portrait bust, preserving approved identity closely: warm fair skin, neat short dark brown side-parted hair swept to viewer right, friendly polished male face with dark oval eyes, gently arched brows, small curved nose, friendly small toothy smile, navy suit jacket, white collar shirt, red tie. Image 1 is identity lock. Image 2 supplies same soft dimensional cartoon shading style. Head and shoulders only, no hands, no props, no symbols or flags, no costume additions. Front-facing as approved thumbnail. Portrait 3:4 canvas with head and shoulders fully contained. Actual transparent background with clean smooth alpha, no backdrop/rounded tile/shadow, no floating speckles, no text, no UI.

## 2-Year-Old

Use case: identity-preserve. Asset type: DayMaker persona portrait. Reconstruct ONLY the cheerful two-year-old toddler in image 1 as high resolution transparent head-and-shoulders portrait matching approved identity. Round warm fair face and round rosy cheeks, large dark oval eyes, short warm orange brown hair with the distinctive small curled top tuft, small ears, cheerful open smile, simple teal crewneck shirt. Image 1 is identity lock; image 2 is only soft dimensional cartoon illustration style reference. Match face proportions and tuft silhouette from approved thumbnail closely. No hat, glasses, hands, toys, extra props, extra clothing, full body. Portrait 3:4 canvas, entire tuft and shoulders inside frame. Actual transparent background with clean smooth alpha, no floating speckles or halo, no rounded tile backdrop, no text or UI.

## Sunglasses cloud

Use case: identity-preserve. Asset type: DayMaker reusable cloud illustration. Reconstruct ONLY the white sunglasses cloud in image 1, with soft blue/lavender shaded underside, dark navy sunglasses, little pink cheeks and small wry grumpy mouth. Image 1 locks approved shape and expression; image 2 gives matching dimensional finish. Remove all caption stickers, lettering, yellow backdrop, stars, border, and any sun behind cloud. Exactly one cloud wearing sunglasses. Low wide rounded fluffy cloud with same organic silhouette as approved reference, centered square canvas, fills 85% width, entire cloud visible. Clean actual transparent background and smooth anti-aliased edges, no floating colored pixels, no floor shadow, no text, no UI.

## Sunglasses sun

Use case: identity-preserve. Asset type: DayMaker weather illustration. Reconstruct ONLY the sun wearing sunglasses from the approved reference as a crisp high resolution cutout. Same cute golden yellow circular sun with short pill shaped rays, navy black sunglasses, small curved smiling mouth. Soft dimensional shading in approved illustration style, not a flat icon. Small balanced rays around circle as shown, all contained on square canvas; subject fills 85% width. No pink cheeks, hands or new props. Actual transparent background with smooth alpha edges; no cream tile, no floor shadow, no colored halos or detached pixels, no text, no UI.

## Coffee cloud

Use case: identity-preserve. Asset type: DayMaker reusable weather illustration. Faithfully reconstruct only the white grumpy coffee cloud in approved reference. Rounded white fluffy wide cloud, pale blue/lavender shaded underside, tiny dark navy eyes, furrowed angled eyebrows, tiny downturned mouth, pink cheeks. A simple brown coffee mug sits beside cloud at lower viewer right with cream rim and small right handle, very subtle steam. Same proportions as reference; soft dimensional cartoon style. Center illustration on square canvas, full silhouette and mug contained, generous transparent margin. Do not add hands or limbs. Actual transparent background, smooth clean alpha, no violet tile, no floor shadow, no caption or text/UI, no colored edge halo or floating pixels.

## Storm cloud

Use case: identity-preserve. Asset type: DayMaker reusable weather illustration. Reconstruct only the storm cloud character from the approved thumbnail. Soft rounded medium slate blue gray fluffy cloud, small dark navy oval eyes, slanting grumpy eyebrows and tiny downturned mouth. Large simple vivid yellow lightning bolt emerges below center; a small golden lightning accent near viewer right side and sparse pale blue raindrops below cloud as in reference. Soft dimensional cartoon shading matching supplied crop, not flat emoji. Center on square canvas with full cloud and lightning contained; subject fills 80% width. Actual transparent background with smooth clean alpha, no mint tile, no floor shadow, no text/UI, no floating colored edge speckles or halo.

## Beach background

Use case: precise-object-edit. Asset type: DayMaker editable meme background. Reconstruct the approved wide beach scene reference at high resolution with ALL TEXT REMOVED. Retain cute large smiling golden yellow sun wearing dark navy sunglasses at LEFT foreground, palm trunk and green fronds at upper left, a few pale rounded beach rocks/cloud-like sand shapes near lower left foreground, calm aqua blue ocean across middle and right, soft clear pale blue sky and sandy beach at bottom. Right HALF remains uncluttered open ocean/sky negative space for editable text layers to be added by app. Same softly shaded premium cartoon illustration style and composition as reference. Wide 3:1 full-bleed rectangular canvas; no rounded corners, border or UI. Absolutely NO words, lettering, captions, labels, logos, watermark or DayMaker text. No new people/objects.

## Rejected hero cleanup attempt

Use case: background-extraction. Precise alpha matte cleanup ONLY of the supplied DayMaker illustration. Preserve every foreground shape, face detail, color, shading, sun ray, sunglasses, and composition exactly. The current cutout has detached stray colored pixels and ragged white/cyan/yellow fringes outside its true silhouette. Remove those edge defects. Make background genuinely fully transparent. Trace a smooth clean anti-aliased silhouette edge around the sun, rays and cloud, with no bright fringe, jagged fragments, halos, glow or colored speckles outside. Do not regenerate a new character or modify expressions. Preserve the original 1:1 canvas and subject scale. No text, no background.

## Rejected Karen cleanup attempt

Use case: background-extraction. Image editing task: repair the alpha edge of this exact portrait, preserve her identity and every foreground pixel as much as possible. Remove ALL isolated red/yellow/pink/white speckles in the background and eliminate the jagged white/yellow edge halo outside her hair and shoulders. Give her a smooth clean cutout silhouette with fully transparent surroundings. Preserve face, hair, sunglasses, earrings, pink blazer, navy top, smile, pose, shading and original portrait scale. No new glow or outline, no colored fringe, no background, no detached particles, no text. This is an edge-matte repair, not a redesign.
