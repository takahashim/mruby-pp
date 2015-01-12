#include "mruby.h"
#include "mruby/array.h"
#include "mruby/value.h"
#include "mruby/variable.h"

static mrb_value
mrb_pp_mcall_any_to_s(mrb_state *mrb, mrb_value obj)
{
  mrb_value any_obj;

  mrb_get_args(mrb, "o", &any_obj);
  return mrb_any_to_s(mrb, any_obj);
}

/*
 * usage:
 *    PP.mcall_kernel_class(self)
 * def:
 *    mod.instance_method(meth).bind(obj).call()
 */
static mrb_value
mrb_pp_mcall_kernel_class(mrb_state *mrb, mrb_value self)
{
  mrb_value obj;

  mrb_get_args(mrb, "o", &obj);
  return mrb_obj_value(mrb_obj_class(mrb, obj));
}

/*
 * usage:
 *    PP.mcall_object_inspect(obj)
 * def:
 *    Object.instance_method(:method).bind(obj).call(:inspect)
 */
static mrb_value
mrb_pp_mcall_object_inspect(mrb_state *mrb, mrb_value self)
{
  mrb_value obj;

  mrb_get_args(mrb, "o", &obj);
  return mrb_obj_inspect(mrb, obj);
}


void
mrb_mruby_pp_gem_init(mrb_state* mrb)
{
  struct RClass *prettyprint;
  struct RClass *pp;

  prettyprint = mrb_define_class(mrb, "PrettyPrint", mrb->object_class);
  pp = mrb_define_class(mrb, "PP", prettyprint);

  mrb_define_class_method(mrb, pp, "mcall_any_to_s", mrb_pp_mcall_any_to_s, MRB_ARGS_REQ(1));
  mrb_define_class_method(mrb, pp, "mcall_kernel_class", mrb_pp_mcall_kernel_class, MRB_ARGS_REQ(1));
  mrb_define_class_method(mrb, pp, "mcall_object_inspect", mrb_pp_mcall_object_inspect, MRB_ARGS_REQ(1));


}

void
mrb_mruby_pp_gem_final(mrb_state* mrb)
{
}
