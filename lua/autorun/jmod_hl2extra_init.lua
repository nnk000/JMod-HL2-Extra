if CLIENT then
	list.Set( "ContentCategoryIcons", "JMod - EZ HL:2 Extra", "jmod_icon_hl2extra.png" )
end

JMod.AdditionalArmorTable = JMod.AdditionalArmorTable or {}

JMod.AdditionalArmorTable["melmet"] = {
	PrintName = "MELMET",
	Category = "JMod - EZ HL:2 Extra",
	mdl = "models/jmod/ez_melmet.mdl",
	clr = {
		r = 255,
		g = 255,
		b = 255
	},
	clrForced = true,
	slots = {
		head = .5,
	},
	def = NonArmorProtectionProfile,
	snds = {
		eq = "physics/flesh/flesh_squishy_impact_hard3.wav",
		uneq = "physics/flesh/flesh_squishy_impact_hard1.wav"
	},
	bon = "ValveBiped.Bip01_Head1",
	siz = Vector(1, 1, 1),
	pos = Vector(0.6, 4.5, 0),
	ang = Angle(-90, 0, -90),
	wgt = 4,
	dur = 10,
	mskmat = "mats_jack_gmod_sprites/one-quarter-from-top-blocked.png",
	ent = "ent_fumo_gmod_ezmelmet"
}