modifier_start_hasted_lua = class({})

function modifier_start_hasted_lua:IsHidden() 	return false end
function modifier_start_hasted_lua:IsPurgable()	return true end
function modifier_start_hasted_lua:IsDebuff() 	return false end

function modifier_start_hasted_lua:GetTexture()
	return "rune_haste"
end

function modifier_start_hasted_lua:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_MOVESPEED_ABSOLUTE
	}
end

function modifier_start_hasted_lua:GetModifierMoveSpeed_Absolute ()
	return 700
end